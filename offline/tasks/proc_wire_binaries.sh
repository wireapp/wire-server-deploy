#!/usr/bin/env bash
set -euo pipefail

if [[ ! $# -eq 1 ]]; then
  echo "usage: $0 OUTPUT_DIR" >&2
  exit 1
fi

OUTPUT_DIR="$1"

echo "Processing wire binaries ${OUTPUT_DIR} ..."

install -m755 "$(nix-build --no-out-link -A pkgs.wire-binaries)/"* "${OUTPUT_DIR}"/binaries/

tar cf "${OUTPUT_DIR}"/binaries.tar -C "${OUTPUT_DIR}" binaries
rm -r "${OUTPUT_DIR}"/binaries
