#!/usr/bin/env bash
set -euo pipefail

INCREMENTAL="${INCREMENTAL:-0}"

# Default exclude list
HELM_CHART_EXCLUDE_LIST="inbucket,wire-server-enterprise"

# Parse the HELM_CHART_EXCLUDE_LIST argument
for arg in "$@"
do
  case $arg in
    HELM_CHART_EXCLUDE_LIST=*)
      HELM_CHART_EXCLUDE_LIST="${arg#*=}"
      ;;
  esac
done
HELM_CHART_EXCLUDE_LIST=$(echo "$HELM_CHART_EXCLUDE_LIST" | jq -R 'split(",")')
echo "Excluding following charts from the release: $HELM_CHART_EXCLUDE_LIST"

# Build the container image
container_image=$(nix-build --no-out-link -A container)
# if [[ -n "${DOCKER_LOGIN:-}" ]];then
#   skopeo copy --dest-creds "$DOCKER_LOGIN" \
#     docker-archive:"$container_image" \
#     "docker://quay.io/wire/wire-server-deploy" \
#     --aditional-tag "$(git rev-parse HEAD)"
# else
#   echo "Skipping container upload, no DOCKER_LOGIN provided"
# fi

mkdir -p containers-{helm,other,system,adminhost}
install -m755 "$container_image" "containers-adminhost/container-wire-server-deploy.tgz"

# Read basic info from .deb packages, write it into debian-builds.json
function write-debian-builds-json() {
  if [ ! -f debian-builds.json ]; then
    echo "[]" > debian-builds.json
  fi

  find debs-jammy/pool/ -type f -name "*.deb" | while read -r pkg; do
    name=$(dpkg-deb --info "$pkg" | awk '/Package:/ {print $2}')
    version=$(dpkg-deb --info "$pkg" | awk '/Version:/ {print $2}')
    source=$(dpkg-deb --info "$pkg" | awk '/Source:/ {print $2}')
    jq --arg name "$name" --arg version "$version" --arg source "$source" \
      '. += [{ name: $name, version: $version, source: $source }]' debian-builds.json > debian-builds.tmp && mv debian-builds.tmp debian-builds.json
  done
}

mirror-apt-jammy debs-jammy
echo "Writing debian-builds.json"
write-debian-builds-json
tar cf debs-jammy.tar debs-jammy
rm -r debs-jammy

fingerprint=$(echo "$GPG_PRIVATE_KEY" | gpg --with-colons --import-options show-only --import --fingerprint  | awk -F: '$1 == "fpr" {print $10; exit}')

echo "$fingerprint"

mkdir -p binaries
install -m755 "$(nix-build --no-out-link -A pkgs.wire-binaries)/"* binaries/
tar cf binaries.tar binaries
rm -r binaries

function list-system-containers() {
# These are manually updated with values from
# https://github.com/kubernetes-sigs/kubespray/blob/release-2.24/roles/kubespray-defaults/defaults/main/download.yml
# TODO: Automate this. This is very wieldy :)
  cat <<EOF
registry.k8s.io/pause:3.9
registry.k8s.io/coredns/coredns:v1.11.4
registry.k8s.io/dns/k8s-dns-node-cache:1.22.28
registry.k8s.io/cpa/cluster-proportional-autoscaler:v1.8.8
registry.k8s.io/metrics-server/metrics-server:v0.7.2
registry.k8s.io/ingress-nginx/controller:v1.10.6
registry.k8s.io/kube-apiserver:v1.28.2
registry.k8s.io/kube-controller-manager:v1.28.2
registry.k8s.io/kube-scheduler:v1.28.2
registry.k8s.io/kube-proxy:v1.28.2
quay.io/coreos/etcd:v3.5.10
quay.io/calico/node:v3.26.4
quay.io/calico/cni:v3.26.4
quay.io/calico/pod2daemon-flexvol:v3.26.4
quay.io/calico/kube-controllers:v3.26.4
quay.io/calico/typha:v3.26.4
quay.io/calico/apiserver:v3.26.4
quay.io/jetstack/cert-manager-controller:v1.16.3
quay.io/jetstack/cert-manager-cainjector:v1.16.3
quay.io/jetstack/cert-manager-webhook:v1.16.3
quay.io/jetstack/cert-manager-startupapicheck:v1.16.3
docker.io/library/nginx:1.25.4-alpine
bats/bats:1.11.1
cr.step.sm/smallstep/step-ca:0.25.3-rc7
registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20231011-8b53cabe0
EOF
}

list-system-containers | create-container-dump containers-system
tar cf containers-system.tar containers-system
[[ "$INCREMENTAL" -eq 0 ]] && rm -r containers-system

legacy_chart_release() {
  # Note: if you want to ship from the develop branch, replace 'repo' url below
  # repo=https://s3-eu-west-1.amazonaws.com/public.wire.com/charts-develop
  repo=https://s3-eu-west-1.amazonaws.com/public.wire.com/charts
  wire_version="4.41.0"
  wire_calling_version="4.40.0"
  
  charts=(
    # backoffice
    # commented out for now, points to a 2.90.0 container image which doesn't
    # seem to exist on quay.io
    # TODO: uncomment once its dependencies are pinned!
    # local-path-provisioner
    ingress-nginx-controller
    nginx-ingress-services
    reaper
    cassandra-external
    databases-ephemeral
    demo-smtp
    elasticsearch-external
    fake-aws
    minio-external
    wire-server
    rabbitmq
    rabbitmq-external
    # federator
  )
  for chartName in "${charts[@]}"; do
    echo "$chartName $repo $wire_version"
  done

  calling_charts=(
    sftd
    coturn
  )
  for chartName in "${calling_charts[@]}"; do
    echo "$chartName $repo $wire_calling_version"
  done
}

wire_build_chart_release () {
  set -euo pipefail
  wire_build="$1"
  curl "$wire_build" | jq -r --argjson HELM_CHART_EXCLUDE_LIST "$HELM_CHART_EXCLUDE_LIST" '
  .helmCharts
  | with_entries(select(.key as $k | $HELM_CHART_EXCLUDE_LIST | index($k) | not))
  | to_entries
  | map("\(.key) \(.value.repo) \(.value.version)")
  | join("\n")
  '
}


# pull_charts() accepts charts in format
# <chart-name> <repo-url> <chart-version>
# on stdin
pull_charts() {
  echo "Pulling charts into ./charts ..."
  mkdir -p ./charts

  home=$(mktemp -d)
  export HELM_CACHE_HOME="$home"
  export HELM_DATA_HOME="$home"
  export HELM_CONFIG_HOME="$home"

  declare -A repos
  # needed to handle associative array lookup
  set +u

  while IFS=$'\n' read -r line
  do
    echo "$line"
    IFS=$' ' read -r -a parts <<< "$line"
    name=${parts[0]}
    repo=${parts[1]}
    version=${parts[2]}

    # we add and update the repo only the first time we see it to speed up the process
    repo_short_name=${repos[$repo]}
    if [ "$repo_short_name" == "" ]; then
      n=${#repos[@]}
      repo_short_name="repo_$((n+1))"
      repos[$repo]=$repo_short_name
      helm repo add "$repo_short_name" "$repo"
      helm repo update "$repo_short_name"
    fi
    (cd ./charts; helm pull --version "$version" --untar "$repo_short_name/$name")
  done
  echo "Pulling charts done."
}

wire_build="https://raw.githubusercontent.com/wireapp/wire-builds/5443da20184574e097ec71a048cfc32d9f85a628/build.json"
wire_build_chart_release "$wire_build" | pull_charts

# Uncomment if you want to create non-wire-build release
# and uncomment the other pull_charts call from aboe
# legacy_chart_release | pull_charts

# TODO: Awaiting some fixes in wire-server regarding tagless images

# Download zauth; as it's needed to generate certificates
wire_version=$(helm show chart ./charts/wire-server | yq -r .version)
echo "quay.io/wire/zauth:$wire_version" | create-container-dump containers-adminhost

function write_wire_binaries_json() {
  echo "Writing wire binaries into wire-binaries.json"
  # "Get" all the binaries from the .nix file
  sed -n '/_version/p' nix/pkgs/wire-binaries.nix | grep -v '\.version' | grep -v 'url' > wire-binaries.json.tmp

  echo "[" > wire-binaries.json.tmp
  # Format it into JSON
  sed -E '/\.url|\.version/!s/([a-z_]+)_version = "(.*)";/{\n  "\1": { "version": "\2" }\n},/' wire-binaries.json.tmp > wire-binaries.json.formatted
  # remove trailing comma -.-
  sed -i '$ s/,$//' wire-binaries.json.formatted
  # remove tmp file
  rm wire-binaries.json.tmp

  echo "]" >> wire-binaries.json.formatted

  mv wire-binaries.json.formatted wire-binaries.json
} 

write_wire_binaries_json

###################################
####### DIRTY HACKS GO HERE #######
###################################

# Patch wire-server values.yaml to include federator
# This is needed to bundle it's image.
sed -i -Ee 's/federation: false/federation: true/' "$(pwd)"/values/wire-server/prod-values.example.yaml
sed -i -Ee 's/useSharedFederatorSecret: false/useSharedFederatorSecret: true/' "$(pwd)"/charts/wire-server/charts/federator/values.yaml

# drop step-certificates/.../test-connection.yaml because it lacks an image tag
# cf. https://github.com/smallstep/helm-charts/pull/196/files
rm -v charts/step-certificates/charts/step-certificates/templates/tests/*

# Get and dump required containers from Helm charts. Omit integration test
# containers (e.g. `quay.io_wire_galley-integration_4.22.0`.)
for chartPath in "$(pwd)"/charts/*; do
  echo "$chartPath"
done | list-helm-containers | grep -v "\-integration:" | create-container-dump containers-helm

# Undo changes on wire-server values.yaml
sed -i -Ee 's/useSharedFederatorSecret: true/useSharedFederatorSecret: false/' "$(pwd)"/charts/wire-server/charts/federator/values.yaml
sed -i -Ee 's/federation: true/federation: false/' "$(pwd)"/values/wire-server/prod-values.example.yaml

patch-ingress-controller-images "$(pwd)"

tar cf containers-helm.tar containers-helm
[[ "$INCREMENTAL" -eq 0 ]] && rm -r containers-helm

echo "docker_ubuntu_repo_repokey: '${fingerprint}'" > ansible/inventory/offline/group_vars/all/key.yml

tar czf assets.tgz debs-jammy.tar binaries.tar containers-adminhost containers-helm.tar containers-system.tar ansible charts values bin debian-builds.json deploy-builds.json wire-builds.json wire-binaries.json

echo "Done"
