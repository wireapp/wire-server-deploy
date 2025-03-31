#!/usr/bin/env bash
set -euo pipefail

echo "Building Linux packages..."

mirror-apt-jammy debs-jammy
tar cf debs-jammy.tar debs-jammy
rm -r debs-jammy

fingerprint=$(echo "$GPG_PRIVATE_KEY" | gpg --with-colons --import-options show-only --import --fingerprint  | awk -F: '$1 == "fpr" {print $10; exit}')

echo "$fingerprint"

echo "docker_ubuntu_repo_repokey: '${fingerprint}'" > ansible/inventory/offline/group_vars/all/key.yml
