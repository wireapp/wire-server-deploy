#!/usr/bin/env bash
set -eou pipefail

mkdir -p static

# Build the container image
container_image=$(nix-build --no-out-link -A container)
if [[ -n "${DOCKER_LOGIN:-}" ]];then
  skopeo copy --dest-creds "$DOCKER_LOGIN" \
    docker-archive:"$container_image" \
    "docker://quay.io/wire/wire-server-deploy:$(git rev-parse HEAD)"
else
  echo "Skipping container upload, no DOCKER_LOGIN provided"
fi

# Build the debs and publish them to static/debs
mirror-bionic static/debs \
  python-apt aufs-tools apt-transport-https software-properties-common conntrack ipvsadm ipset curl rsync socat unzip e2fsprogs xfsprogs ebtables python3-minimal \
  openjdk-8-jdk iproute2 procps libjemalloc1 # for kubespray, cassandra

# Copy the binaries to static/binaries
mkdir -p static/binaries
cp -R "$(nix-build --no-out-link -A pkgs.wire-binaries)/"* static/binaries/

function list-containers() {
  kubeadm config images list --kubernetes-version v1.18.10
  cat ./kubespray_additional_containers.txt
  echo "quay.io/wire/restund:0.4.14w7b1.0.47"
  download-helm-charts static/charts | list-helm-containers
}

# Dump docker containers to static/containers
list-containers | create-container-dump static/containers

# create static/containers/index.txt
(cd static/containers; for f in *.tar; do echo "$f";done) > static/containers/index.txt

# create static/charts/index.txt
(cd static/charts; for f in *.tgz; do echo "$f";done) > static/charts/index.txt
