#!/usr/bin/env bash

set -euxo pipefail

CD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${CD_DIR}/../terraform/examples/wiab-demo-hetzner"
# shellcheck disable=SC2034  # May be used in future versions
BIN_DIR="${CD_DIR}/../bin"
# shellcheck disable=SC2034  # May be used in future versions
ARTIFACTS_DIR="${CD_DIR}/demo-build/output"
ANSIBLE_DIR="${CD_DIR}/../ansible"
INVENTORY_DIR="${ANSIBLE_DIR}/inventory/demo"
INVENTORY_FILE="${INVENTORY_DIR}/host.yml"
TEST_USER="demo"
COMMIT_HASH="${GITHUB_SHA}"

function cleanup {
  (cd "$TF_DIR" && terraform destroy -auto-approve)
  echo done
}
#trap cleanup EXIT

cd "$TF_DIR"
terraform init && terraform apply -auto-approve

host=$(terraform output -raw host)
ssh_private_key=$(terraform output ssh_private_key)

rm -f "${INVENTORY_DIR}/ssh_private_key" || true
echo "$ssh_private_key" > "${INVENTORY_DIR}/ssh_private_key"
chmod 400 "${INVENTORY_DIR}/ssh_private_key"

# clean old host verification keys to avoid SSH issues
ssh-keygen -R "$host" || true

# create demo user on the remote host
ssh -v -oStrictHostKeyChecking=accept-new -oConnectionAttempts=10 -i "${INVENTORY_DIR}/ssh_private_key" "root@$host" \
"useradd -m -s /bin/bash ${TEST_USER} && \
usermod -aG sudo ${TEST_USER} && \
mkdir -p /home/${TEST_USER}/.ssh && \
cp /root/.ssh/authorized_keys /home/${TEST_USER}/.ssh/ && \
chown -R ${TEST_USER}:${TEST_USER} /home/${TEST_USER}/.ssh && \
chmod 700 /home/${TEST_USER}/.ssh && \
chmod 600 /home/${TEST_USER}/.ssh/authorized_keys && \
echo '${TEST_USER} ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers.d/${TEST_USER}"

yq -yi ".wiab.hosts.deploy_node.ansible_host = \"$host\"" "${INVENTORY_FILE}"
yq -yi ".wiab.hosts.deploy_node.ansible_ssh_private_key_file = \"${INVENTORY_DIR}/ssh_private_key\"" "${INVENTORY_FILE}"
yq -yi ".wiab.vars.artifact_hash = \"$COMMIT_HASH\"" "${INVENTORY_FILE}"
yq -yi ".wiab.hosts.deploy_node.ansible_user = \"$TEST_USER\"" "${INVENTORY_FILE}"
cat "${INVENTORY_DIR}/ssh_private_key"
cat "${INVENTORY_FILE}"

echo "Running ansible playbook deploy_wiab.yml against node $host"
# deploying demo-wiab
ansible-playbook -i "${INVENTORY_FILE}" "${ANSIBLE_DIR}/wiab-demo/deploy_wiab.yml" --skip-tags verify_dns
# cleaning demo-wiab
ansible-playbook -i "${INVENTORY_FILE}" "${ANSIBLE_DIR}/wiab-demo/clean_cluster.yml" --tags remove_minikube,remove_artifacts,remove_packages,remove_iptables,remove_ssh
