#!/usr/bin/env bash
set -x -euo pipefail

if [[ ! $# -eq 2 ]]; then
  echo "usage: $0 OUTPUT-DIR ROOT-DIR" >&2
  exit 1
fi

OUTPUT_DIR="$1"
ROOT_DIR="$2"

echo "Building Linux packages ${OUTPUT_DIR} ..."

function write-debian-builds-json() {
  
  JSON_FILE="${OUTPUT_DIR}/versions/debian-builds.json"
  echo "Creating $JSON_FILE"
  echo "[]" > "$JSON_FILE"

  find "${OUTPUT_DIR}/debs-jammy/pool/" -type f -name "*.deb" | while read -r pkg; do
    pkg_info=$(dpkg-deb --info "$pkg")
    name=$(echo "$pkg_info" | awk '/Package:/ {print $2}')
    version=$(echo "$pkg_info" | awk '/Version:/ {print $2}')
    source=$(echo "$pkg_info" | awk '/Source:/ {print $2}')
    jq --arg name "$name" --arg version "$version" --arg source "$source" \
      '. += [{ name: $name, version: $version, source: $source }]' "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
  done
}

mirror-apt-jammy "${OUTPUT_DIR}"/debs-jammy
write-debian-builds-json

tar cf "${OUTPUT_DIR}"/debs-jammy.tar -C "${OUTPUT_DIR}" debs-jammy
rm -r "${OUTPUT_DIR}"/debs-jammy

fingerprint=$(echo "$GPG_PRIVATE_KEY" | gpg --with-colons --import-options show-only --import --fingerprint  | awk -F: '$1 == "fpr" {print $10; exit}')

echo "$fingerprint"

echo "docker_ubuntu_repo_repokey: '${fingerprint}'" > "${ROOT_DIR}"/ansible/inventory/offline/group_vars/all/key.yml
