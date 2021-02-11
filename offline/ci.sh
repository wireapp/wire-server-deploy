#!/usr/bin/env bash
set -eou pipefail

mkdir -p assets

# Build the container image
container_image=$(nix-build --no-out-link -A container)
if [[ -n "${DOCKER_LOGIN:-}" ]];then
  skopeo copy --dest-creds "$DOCKER_LOGIN" \
    docker-archive:"$container_image" \
    "docker://quay.io/wire/wire-server-deploy:$(git rev-parse HEAD)"
else
  echo "Skipping container upload, no DOCKER_LOGIN provided"
fi

mkdir -p assets/containers-{helm,other,system}
install -m755 "$container_image" assets/containers-other/

# Build the debs and publish them to assets/debs
# mirror-apt assets/debs

# Copy the binaries to assets/binaries
mkdir -p assets/binaries
install -m755 "$(nix-build --no-out-link -A pkgs.wire-binaries)/"* assets/binaries/


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

list-system-containers | create-container-dump assets/containers-system

# Used for ansible-restund role
echo "quay.io/wire/restund:0.4.14w7b1.0.47" | create-container-dump assets/containers-other

charts=(
  # backoffice
  # commented out for now, points to a 2.90.0 container image which doesn't
  # seem to exist on quay.io
  nginx-ingress-controller
  nginx-ingress-services
  reaper
  cassandra-external
  databases-ephemeral
  demo-smtp
  elasticsearch-external
  fake-aws
  minio-external
  wire-server
  local-path-provisioner
  sftd
  # Has a weird dependency on curl:latest. out of scope
  # wire-server-metrics
  # fluent-bit
  # kibana
)

# TODO: Awaiting some fixes in wire-server regarding tagless images

# HELM_HOME=$(mktemp -d)
# export HELM_HOME
#
# helm repo add wire https://s3-eu-west-1.amazonaws.com/public.wire.com/charts
#
# for chart in "${charts[@]}"; do
#   echo "wire/$chart"
# done | list-helm-containers | create-container-dump assets/containers-helm
#
# cp -R values assets/
# cp -R ansible assets/

echo "Done"
