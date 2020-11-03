#!/usr/bin/env bash
set -eou pipefail

mkdir -p static

# Build the debs and publish them to static/debs
mirror-bionic static/debs \
  python-apt aufs-tools apt-transport-https software-properties-common conntrack ipvsadm ipset curl rsync socat unzip e2fsprogs xfsprogs ebtables python3-minimal \
  openjdk-8-jdk iproute2 procps libjemalloc1 # for kubespray, cassandra

# Copy the binaries to static/binaries
mkdir -p static/binaries
cp -R "$(nix-build --no-out-link -A pkgs.wire-binaries)/"* static/binaries/

# Dump docker containers to static/containers
(kubeadm config images list --kubernetes-version v1.18.10; cat ./kubespray_additional_containers.txt) | create-container-dump static/containers

# create static/containers/index.txt
(cd static/containers; for f in *.tar; do echo "$f";done) > static/containers/index.txt

# TODO: add helm chart containers here
