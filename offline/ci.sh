#!/usr/bin/env bash
set -euo pipefail

# CONTAINER-ARCHIVES
# Populate the `container-archives` folder.
# It contains all the containers that we need to directly load into our container runtime.
mkdir -p container-archives

# wire-server-deploy
install -m755 $(nix-build --no-out-link -A container) "container-archives/wire-server-deploy.tgz"

# registry
skopeo copy --insecure-policy --dest-compress \
  docker://registry:2.8.1 \
  docker-archive:container-archives/registry.tgz


# DEBS
# Create a debian mirror. We need to provide a bunch of packages that are used
# by the playbooks, as well as docker-ce, so we can run the containers we need
# to run the tooling and the registry itself.
mirror-apt debs
tar cf debs.tar debs
rm -r debs
fingerprint=$(echo "$GPG_PRIVATE_KEY" | gpg --with-colons --import-options show-only --import --fingerprint  | awk -F: '$1 == "fpr" {print $10; exit}')
echo "$fingerprint"
echo "docker_ubuntu_repo_repokey: '${fingerprint}'" > ansible/inventory/offline/group_vars/all/key.yml


# BINARIES
# The tooling expects to be able to download some binaries.
# These are built by our wire-binaries Nix derivation.
mkdir -p binaries
install -m755 "$(nix-build --no-out-link -A pkgs.wire-binaries)/"* binaries/
tar cf binaries.tar binaries
rm -r binaries

# REGISTRY CONTENTS
# All other container images get served by a local container registry, usually
# served from the assethost.
# We temporarily spin up a registry in CI, push all the container images to it,
# and later put its state dir into the CI artifact.

mkdir -p registry-contents
# start the registry
docker run -d -p 5000:5000 \
  --restart always \
  --name registry \
  -v $PWD/registry-contents:/var/lib/registry \
  registry:2.8.1

function push-to-registry() {
  while IFS= read -r image;do
    echo "At image ${image}"
    echo skopeo copy --insecure-policy --dest-compress \
      docker://$image \
      docker://registry:5000/$image
    skopeo copy --insecure-policy --dest-compress \
      docker://$image \
      docker://registry:5000/$image
  done
}

function list-system-containers() {
# These are manually updated with values from
# ansible/roles-external/kubespray/roles/download/defaults/main.yml
# TODO: Automate this. This is very wieldy :)
  cat <<EOF
k8s.gcr.io/kube-apiserver:v1.23.7
k8s.gcr.io/kube-controller-manager:v1.23.7
k8s.gcr.io/kube-scheduler:v1.23.7
k8s.gcr.io/kube-proxy:v1.23.7
quay.io/coreos/etcd:v3.5.3
quay.io/calico/node:v3.22.3
quay.io/calico/cni:v3.22.3
quay.io/calico/kube-controllers:v3.22.3
docker.io/library/nginx:1.21.4
k8s.gcr.io/dns/k8s-dns-node-cache:1.21.1
k8s.gcr.io/cpa/cluster-proportional-autoscaler-amd64:1.8.5
k8s.gcr.io/pause:3.3
k8s.gcr.io/pause:3.6
k8s.gcr.io/etcd:3.5.1-0
k8s.gcr.io/coredns/coredns:v1.8.6
docker.io/kubernetesui/dashboard-amd64:v2.5.0
docker.io/kubernetesui/metrics-scraper:v1.0.7
EOF
}

list-system-containers | push-to-registry

# Used for ansible-restund role
echo "quay.io/wire/restund:v0.4.16b1.0.53" | push-to-registry

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
  wire/sftd
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

# wire_version=$(helm show chart wire/wire-server | yq -r .version)
wire_version="4.12.0"

# Download zauth; as it's needed to generate certificates
echo "quay.io/wire/zauth:$wire_version" | push-to-registry

mkdir -p ./charts
for chartName in "${charts[@]}"; do
  (cd ./charts; helm pull --version "$wire_version" --untar "$chartName")
done

for chartPath in "$(pwd)"/charts/*; do
  echo "$chartPath"
done | list-helm-containers | push-to-registry

docker stop registry


# PACKAGING
# Package up all from above.
tar czf assets.tgz debs.tar binaries.tar ansible bin container-archives charts registry-contents values

echo "Done"
