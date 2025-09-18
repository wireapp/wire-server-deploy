#!/usr/bin/env bash

set -euo pipefail

CD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${CD_DIR}/../terraform/examples/wiab-demo-hetzner"
BIN_DIR="${CD_DIR}/../bin"
ARTIFACTS_DIR="${CD_DIR}/demo-build/output"
ANSIBLE_DIR="${CD_DIR}/../ansible"
INVENTORY_DIR="${ANSIBLE_DIR}/inventory/demo"
INVENTORY_FILE="${INVENTORY_DIR}/host.yml"

COMMIT_HASH="${GITHUB_SHA}"

cd "$TF_DIR"
terraform init && terraform apply -auto-approve

host=$(terraform output -raw host)
ssh_private_key=$(terraform output ssh_private_key)

rm -f "${INVENTORY_DIR}/ssh_private_key" || true
echo "$ssh_private_key" > "${INVENTORY_DIR}/ssh_private_key"
chmod 400 "${INVENTORY_DIR}/ssh_private_key"

yq -yi ".wiab.hosts.deploy_node.ansible_host = \"$host\"" "${INVENTORY_FILE}"
yq -yi ".wiab.hosts.deploy_node.ansible_ssh_private_key_file = \"${INVENTORY_DIR}/ssh_private_key\"" "${INVENTORY_FILE}"
yq -yi ".wiab.vars.artifact_hash = \"$COMMIT_HASH\"" "${INVENTORY_FILE}"
yq -yi '.wiab.hosts.deploy_node.ansible_user = "root"' "${INVENTORY_FILE}"

echo "Running ansible playbook deploy_wiab.yml against node $host"
# deploying demo-wiab
ansible-playbook -i "${INVENTORY_FILE}" "${ANSIBLE_DIR}/wiab-demo/deploy_wiab.yml" --skip-tags verify_dns
# cleaning demo-wiab
ansible-playbook -i "${INVENTORY_FILE}" "${ANSIBLE_DIR}/wiab-demo/clean_cluster.yml" --tags remove_minikube,remove_artifacts,remove_packages,remove_iptables,remove_ssh
