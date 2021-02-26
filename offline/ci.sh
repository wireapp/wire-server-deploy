#!/usr/bin/env bash
set -eou pipefail

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

mirror-apt debs

tar cf debs.tar debs

fingerprint=$(echo "$GPG_PRIVATE_KEY" | gpg --with-colons --import-options show-only --import --fingerprint  | awk -F: '$1 == "fpr" {print $10; exit}')

echo "$fingerprint"

mkdir -p binaries
install -m755 "$(nix-build --no-out-link -A pkgs.wire-binaries)/"* binaries/
tar cf binaries.tar binaries


function list-system-containers() {
# These are manually updated with values from
# https://github.com/kubernetes-sigs/kubespray/blob/release-2.15/roles/download/defaults/main.yml
# TODO: Automate this. This is very wieldy :)
  cat <<EOF
k8s.gcr.io/kube-apiserver:v1.19.7
k8s.gcr.io/kube-controller-manager:v1.19.7
k8s.gcr.io/kube-scheduler:v1.19.7
k8s.gcr.io/kube-proxy:v1.19.7
quay.io/coreos/etcd:v3.4.13
quay.io/calico/node:v3.16.5
quay.io/calico/cni:v3.16.5
quay.io/calico/kube-controllers:v3.16.5
docker.io/library/nginx:1.19
k8s.gcr.io/coredns:1.7.0
k8s.gcr.io/dns/k8s-dns-node-cache:1.16.0
k8s.gcr.io/cpa/cluster-proportional-autoscaler-amd64:1.8.3
k8s.gcr.io/pause:3.3
docker.io/kubernetesui/dashboard-amd64:v2.1.0
docker.io/kubernetesui/metrics-scraper:v1.0.6
EOF
}

list-system-containers | create-container-dump containers-system
tar cf containers-system.tar containers-system

# Used for ansible-restund role
echo "quay.io/wire/restund:0.4.14w7b1.0.47" | create-container-dump containers-other
tar cf containers-other.tar containers-other


charts=(
  # backoffice
  # commented out for now, points to a 2.90.0 container image which doesn't
  # seem to exist on quay.io
  wire/nginx-ingress-controller
  wire/nginx-ingress-services
  wire/reaper
  wire/cassandra-external
  wire/databases-ephemeral
  wire/demo-smtp
  wire/elasticsearch-external
  wire/fake-aws
  wire/minio-external
  wire/wire-server
  # local-path-provisioner
  # TODO: uncomment once its dependencies are pinned!
  # wire/sftd
  # Has a weird dependency on curl:latest. out of scope
  # wire-server-metrics
  # fluent-bit
  # kibana
)

# TODO: Awaiting some fixes in wire-server regarding tagless images

HELM_HOME=$(mktemp -d)
export HELM_HOME

helm repo add wire https://s3-eu-west-1.amazonaws.com/public.wire.com/charts
helm repo update

wire_version=$(helm show chart wire/wire-server | yq -r .version)

# Download zauth; as it's needed to generate certificates
echo "quay.io/wire/zauth:$wire_version" | create-container-dump containers-adminhost

mkdir -p charts
for chart in "${charts[@]}"; do
  (cd charts; helm pull --untar "$chart")
done

for chart in "${charts[@]}"; do
  echo "$chart"
done | list-helm-containers | create-container-dump containers-helm

tar cf containers-helm.tar containers-helm

#
echo "docker_ubuntu_repo_repokey: '${fingerprint}'" > ansible/inventory/offline/group_vars/all/key.yml


tar czf assets.tgz debs.tar binaries.tar containers-adminhost containers-helm.tar containers-other.tar containers-system.tar ansible charts values bin

echo "Done"
