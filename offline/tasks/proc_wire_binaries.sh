#!/usr/bin/env bash
set -euo pipefail

if [[ ! $# -eq 1 ]]; then
  echo "usage: $0 OUTPUT_DIR" >&2
  exit 1
fi

OUTPUT_DIR="$1"

echo "Processing wire binaries ${OUTPUT_DIR} ..."

ORIGINAL_DIR="$PWD"
cd "${OUTPUT_DIR}" || { echo "Error: Cannot change to directory ${OUTPUT_DIR}/debs-jammy"; exit 1; }

install -m755 "$(nix-build --no-out-link -A pkgs.wire-binaries)/"* binaries/
tar cf binaries.tar binaries
rm -r binaries

cd "$ORIGINAL_DIR" || { echo "Error: Cannot change back to original directory"; exit 1; }
