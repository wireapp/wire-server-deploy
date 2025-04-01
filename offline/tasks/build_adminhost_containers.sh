#!/usr/bin/env bash
set -euo pipefail

if [[ ! $# -eq 1 ]]; then
  echo "usage: $0 OUTPUT-DIR" >&2
  exit 1
fi

OUTPUT_DIR="$1"

echo "Building admin container images ${OUTPUT_DIR} ..."

# Build the container image
container_image=$(nix-build --no-out-link -A container)

ORIGINAL_DIR="$PWD"
cd "${OUTPUT_DIR}" || { echo "Error: Cannot change to directory ${OUTPUT_DIR}/debs-jammy"; exit 1; }
install -m755 "$container_image" containers-adminhost/container-wire-server-deploy.tgz

# Download zauth; as it's needed to generate certificates
wire_version=$(helm show chart charts/wire-server | yq -r .version)
echo "quay.io/wire/zauth:$wire_version" | create-container-dump containers-adminhost

cd "$ORIGINAL_DIR" || { echo "Error: Cannot change back to original directory"; exit 1; }
