#!/usr/bin/env bash
set -euo pipefail

INCREMENTAL="${INCREMENTAL:-0}"

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

mirror-apt-jammy debs-jammy
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
registry.k8s.io/coredns/coredns:v1.10.1
registry.k8s.io/dns/k8s-dns-node-cache:1.22.28
registry.k8s.io/cpa/cluster-proportional-autoscaler:v1.8.8
registry.k8s.io/metrics-server/metrics-server:v0.6.4
registry.k8s.io/sig-storage/local-volume-provisioner:v2.5.0
registry.k8s.io/ingress-nginx/controller:v1.9.4
registry.k8s.io/sig-storage/csi-attacher:v3.3.0
registry.k8s.io/sig-storage/csi-provisioner:v3.0.0
registry.k8s.io/sig-storage/csi-snapshotter:v5.0.0
registry.k8s.io/sig-storage/snapshot-controller:v4.2.1
registry.k8s.io/sig-storage/csi-resizer:v1.3.0
registry.k8s.io/sig-storage/csi-node-driver-registrar:v2.4.0
registry.k8s.io/kube-apiserver:v1.28.2
registry.k8s.io/kube-controller-manager:v1.28.2
registry.k8s.io/kube-scheduler:v1.28.2
registry.k8s.io/kube-proxy:v1.28.2
quay.io/coreos/etcd:v3.5.9
quay.io/cilium/cilium:v1.13.4
quay.io/cilium/operator:v1.13.4
quay.io/cilium/hubble-relay:v1.13.4
quay.io/cilium/certgen:v0.1.8
quay.io/cilium/hubble-ui:v0.11.0
quay.io/cilium/hubble-ui-backend:v0.11.0
quay.io/calico/node:v3.26.4
quay.io/calico/cni:v3.26.4
quay.io/calico/pod2daemon-flexvol:v3.26.4
quay.io/calico/kube-controllers:v3.26.4
quay.io/calico/typha:v3.26.4
quay.io/calico/apiserver:v3.26.4
quay.io/jetstack/cert-manager-controller:v1.13.2
quay.io/jetstack/cert-manager-cainjector:v1.13.2
quay.io/jetstack/cert-manager-webhook:v1.13.2
quay.io/jetstack/cert-manager-ctl:v1.13.2
quay.io/metallb/speaker:v0.13.9
quay.io/metallb/controller:v0.13.9
docker.io/library/nginx:1.25.2-alpine
docker.io/kubernetesui/dashboard:v2.7.0
docker.io/kubernetesui/metrics-scraper:v1.0.8
EOF
}

list-system-containers | create-container-dump containers-system
tar cf containers-system.tar containers-system
[[ "$INCREMENTAL" -eq 0 ]] && rm -r containers-system

# Used for ansible-restund role
echo "quay.io/wire/restund:v0.6.0-rc.2" | create-container-dump containers-other
tar cf containers-other.tar containers-other
[[ "$INCREMENTAL" -eq 0 ]] && rm -r containers-other

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
    restund
    coturn
  )
  for chartName in "${calling_charts[@]}"; do
    echo "$chartName $repo $wire_calling_version"
  done
}

wire_build_chart_release () {
  set -euo pipefail
  wire_build="$1"
  curl "$wire_build" | jq -r '.helmCharts | with_entries(select(.key != "inbucket")) | to_entries | map("\(.key) \(.value.repo) \(.value.version)") | join("\n") '
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

wire_build="https://raw.githubusercontent.com/wireapp/wire-builds/7469e52b0ef12f5dd0af08d11ea7ed231b31f5e1/build.json"
wire_build_chart_release "$wire_build" | pull_charts

# Uncomment if you want to create non-wire-build release
# and uncomment the other pull_charts call from aboe
# legacy_chart_release | pull_charts

# TODO: Awaiting some fixes in wire-server regarding tagless images

# Download zauth; as it's needed to generate certificates
wire_version=$(helm show chart ./charts/wire-server | yq -r .version)
echo "quay.io/wire/zauth:$wire_version" | create-container-dump containers-adminhost

###################################
####### DIRTY HACKS GO HERE #######
###################################

# Patch wire-server values.yaml to include federator
# This is needed to bundle it's image.
sed -i -Ee 's/federation: false/federation: true/' "$(pwd)"/values/wire-server/prod-values.example.yaml
sed -i -Ee 's/useSharedFederatorSecret: false/useSharedFederatorSecret: true/' "$(pwd)"/charts/wire-server/charts/federator/values.yaml

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

tar czf assets.tgz debs-jammy.tar binaries.tar containers-adminhost containers-helm.tar containers-other.tar containers-system.tar ansible charts values bin

echo "Done"
