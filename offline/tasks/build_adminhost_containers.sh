#!/usr/bin/env bash
set -euo pipefail

echo "Building admin container images..."

# Build the container image
container_image=$(nix-build --no-out-link -A container)
install -m755 "$container_image" "containers-adminhost/container-wire-server-deploy.tgz"

# Download zauth; as it's needed to generate certificates
wire_version=$(helm show chart ./charts/wire-server | yq -r .version)
echo "quay.io/wire/zauth:$wire_version" | create-container-dump containers-adminhost
