#!/usr/bin/env bash
set -euo pipefail

if [[ ! $# -eq 1 ]]; then
  echo "usage: $0 OUTPUT-DIR" >&2
  exit 1
fi

OUTPUT_DIR="$1"

echo "Building admin container images $OUTPUT_DIR ..."

# Build the container image
container_image=$(nix-build --no-out-link -A container)
install -m755 "$container_image" "$OUTPUT_DIR/containers-adminhost/container-wire-server-deploy.tgz"

# Download zauth; as it's needed to generate certificates
wire_version=$(helm show chart $OUTPUT_DIR/charts/wire-server | yq -r .version)
echo "quay.io/wire/zauth:$wire_version" | create-container-dump $OUTPUT_DIR/containers-adminhost
