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
install -m755 "$(nix-build --no-out-link -A pkgs.wire-binaries)/"* static/binaries/


function list-system-containers() {
  kubeadm config images list --kubernetes-version v1.18.10
  cat ./kubespray_additional_containers.txt
}

list-system-containers | create-container-dump static/system-containers

echo "quay.io/wire/restund:0.4.14w7b1.0.47" | create-container-dump static/other-containers

charts=(
  # backoffice
  # commented out for now, points to a 2.90.0 container image which doesn't
  # seem to exist on quay.io
  nginx-ingress-controller
  nginx-ingress-services
  reaper
  cassandra-external
  redis-ephemeral
  demo-smtp
  elasticsearch-external
  fake-aws
  minio-external
  wire-server
  # Has a weird dependency on curl:latest. out of scope
  # wire-server-metrics
  # fluent-bit
  # kibana
)

for f in charts/*; do
  ./bin/update.sh $f
done

for chart in "${charts[@]}"; do
  echo "charts/$chart"
done | list-helm-containers | create-container-dump static/helm-containers

cp -R charts static/

cp -R ansible static/
