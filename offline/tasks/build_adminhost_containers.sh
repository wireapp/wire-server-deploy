#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 OUTPUT-DIR [--adminhost] [--zauth]" >&2
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

OUTPUT_DIR="$1"
shift

ADMINHOST=false
ZAUTH=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --adminhost)
      ADMINHOST=true
      ;;
    --zauth)
      ZAUTH=true
      ;;
    *)
      usage
      ;;
  esac
  shift
done

if [ "$ADMINHOST" = false ] && [ "$ZAUTH" = false ]; then
  echo "Error: Neither --adminhost nor --zauth option was passed. At least one is required." >&2
  usage
fi

if [ "$ADMINHOST" = true ]; then
  echo "Building adminhost container images in ${OUTPUT_DIR} ..."
  container_image=$(nix-build --no-out-link -A container)
  install -m755 "$container_image" "${OUTPUT_DIR}"/containers-adminhost/container-wire-server-deploy.tgz
fi

if [ "$ZAUTH" = true ]; then
  echo "Building zauth container image in ${OUTPUT_DIR} ..."
  wire_version=$(helm show chart "${OUTPUT_DIR}"/charts/wire-server | yq -r .version)
  echo "quay.io/wire/zauth:$wire_version" | create-container-dump "${OUTPUT_DIR}"/containers-adminhost
fi
