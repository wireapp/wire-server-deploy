#!/usr/bin/env bash

set -eou pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(cd "$SCRIPT_DIR/../../ansible" && pwd)"

ls $ANSIBLE_DIR/inventory/offline

if [ -f "$ANSIBLE_DIR/inventory/offline/hosts.ini" ]; then
  INVENTORY_FILE="$ANSIBLE_DIR/inventory/offline/hosts.ini"
elif [ -f "$ANSIBLE_DIR/inventory/offline/inventory.yml" ]; then
  INVENTORY_FILE="$ANSIBLE_DIR/inventory/offline/inventory.yml"
else
  echo "No inventory file in ansible/inventory/offline/. Please supply an $ANSIBLE_DIR/inventory/offline/inventory.yml or $ANSIBLE_DIR/inventory/offline/hosts.ini"
  exit 1
fi

if [ -f "$ANSIBLE_DIR/inventory/offline/hosts.ini" ] && [ -f "$ANSIBLE_DIR/inventory/offline/inventory.yml" ]; then
  echo "Both hosts.ini and inventory.yml provided in ansible/inventory/offline! Pick only one."
  exit 1
fi

echo "using ansible inventory: $INVENTORY_FILE"

# If this step fails partway, and you know that parts of it completed, the `--skip-tags debs,binaries,containers,containers-helm,containers-other` tags may come in handy.
ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR"/setup-offline-sources.yml

# With ctr being installed on all nodes that need it, seed all container images:
ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR"/seed-offline-containerd.yml

# Install NTP
ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR"/sync_time.yml -v
