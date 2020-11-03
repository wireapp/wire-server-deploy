#!/usr/bin/env bash

# Build and install the environment
nix-env -f default.nix -iA env

mkdir -p static

# Build the debs and publish them to static/debs
mirror-bionic static/debs \
  python-apt aufs-tools apt-transport-https software-properties-common conntrack ipvsadm ipset curl rsync socat unzip e2fsprogs xfsprogs ebtables python3-minimal \
  openjdk-8-jdk iproute2 procps libjemalloc1 # for kubespray, cassandra

# Copy the binaries to static/binaries
mkdir -p static/binaries
cp -R "$(nix-build --no-out-link -A pkgs.wire-binaries)/"* static/binaries/
