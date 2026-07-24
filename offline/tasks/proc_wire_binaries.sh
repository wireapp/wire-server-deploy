#!/usr/bin/env bash
set -euo pipefail

if [[ ! $# -eq 2 ]]; then
  echo "usage: $0 OUTPUT_DIR ROOT_DIR" >&2
  exit 1
fi

OUTPUT_DIR="$1"
ROOT_DIR="$2"

echo "Processing wire binaries ${OUTPUT_DIR} ..."

install -m755 "$(nix-build --no-out-link -A pkgs.wire-binaries)/"* "${OUTPUT_DIR}"/binaries/

tar cf "${OUTPUT_DIR}"/binaries.tar -C "${OUTPUT_DIR}" binaries
rm -r "${OUTPUT_DIR}"/binaries

function write_wire_binaries_json() {
  temp_dir=$(mktemp -d -p "${OUTPUT_DIR}")

  # "Get" all the binaries from the .nix file
  sed -n '/_version/p' "${ROOT_DIR}/nix/pkgs/wire-binaries.nix" | grep -v '\.version' | grep -v 'url' > "${temp_dir}/wire-binaries.json.tmp"

  echo "[" > "${temp_dir}/wire-binaries.json.formatted"
  # Format it into JSON
  sed -E '/\.url|\.version/!s/([a-z_]+)_version = "(.*)";/{\n  "\1": { "version": "\2" }\n},/' "${temp_dir}/wire-binaries.json.tmp" >> "${temp_dir}/wire-binaries.json.formatted"
  # remove trailing comma -.-
  sed -i '$ s/,$//' "${temp_dir}/wire-binaries.json.formatted"
  
  echo "]" >> "${temp_dir}/wire-binaries.json.formatted"

  echo "Writing wire binaries into ${OUTPUT_DIR}/versions/wire-binaries.json"
  mv "${temp_dir}/wire-binaries.json.formatted" "${OUTPUT_DIR}/versions/wire-binaries.json"
  rm -rf "${temp_dir}"
} 

write_wire_binaries_json
