#!/usr/bin/env bash
set -euo pipefail

if [[ ! $# -eq 1 ]]; then
  echo "usage: $0 OUTPUT-DIR" >&2
  exit 1
fi

OUTPUT_DIR="$1"

echo "Processing wire binaries ${OUTPUT-DIR} ..."

install -m755 "$(nix-build --no-out-link -A pkgs.wire-binaries)/"* ${OUTPUT-DIR}/binaries/
tar cf ${OUTPUT-DIR}/binaries.tar ${OUTPUT-DIR}/binaries
rm -r ${OUTPUT-DIR}/binaries
