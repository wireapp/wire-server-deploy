#!/usr/bin/env bash
set -euo pipefail

if [[ ! $# -eq 2 ]]; then
  echo "usage: $0 OUTPUT-DIR ROOT-DIR" >&2
  exit 1
fi

OUTPUT_DIR="$1"
ROOT_DIR="$2"

echo "Building Linux packages ${OUTPUT_DIR} ..."

ORIGINAL_DIR="$PWD"
cd "${OUTPUT_DIR}" || { echo "Error: Cannot change to directory ${OUTPUT_DIR}/debs-jammy"; exit 1; }

mirror-apt-jammy debs-jammy
tar cf debs-jammy.tar debs-jammy
rm -r debs-jammy

cd "$ORIGINAL_DIR" || { echo "Error: Cannot change back to original directory"; exit 1; }

fingerprint=$(echo "$GPG_PRIVATE_KEY" | gpg --with-colons --import-options show-only --import --fingerprint  | awk -F: '$1 == "fpr" {print $10; exit}')

echo "$fingerprint"

echo "docker_ubuntu_repo_repokey: '${fingerprint}'" > "${ROOT_DIR}"/ansible/inventory/offline/group_vars/all/key.yml
