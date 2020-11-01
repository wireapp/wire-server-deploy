#!/usr/bin/env bash
set -eou pipefail

ansible_inventory=$(terraform output -json ansible-inventory)
bastion_hostname=$(echo $ansible_inventory | jq -r ._meta.hostvars.bastion.ansible_host)
bastion_username=$(echo $ansible_inventory | jq -r ._meta.hostvars.bastion.ansible_user)

node_hostname=$(echo $ansible_inventory | jq -r ._meta.hostvars.$1.ansible_host)
node_username=$(echo $ansible_inventory | jq -r ._meta.hostvars.$1.ansible_user)

ssh -J $bastion_username@$bastion_hostname $node_username@$node_hostname
