#!/usr/bin/env bash

set -euo pipefail

CD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${CD_DIR}/../terraform/examples/wire-server-deploy-offline-hetzner"
BIN_DIR="${CD_DIR}/../bin"
ARTIFACTS_DIR="${CD_DIR}/default-build/output"

function cleanup {
  (cd "$TF_DIR" && terraform destroy -auto-approve)
  echo done
}
trap cleanup EXIT

cd "$TF_DIR"
terraform init && terraform apply -auto-approve

adminhost=$(terraform output adminhost)
adminhost="${adminhost//\"/}" # remove extra quotes around the returned string
ssh_private_key=$(terraform output ssh_private_key)

eval `ssh-agent`
ssh-add - <<< "$ssh_private_key"

terraform output -json static-inventory > inventory.json
cat inventory.json | yq eval -P - > inventory.yml

ssh -oStrictHostKeyChecking=accept-new -oConnectionAttempts=10 "root@$adminhost" tar xzv < "$ARTIFACTS_DIR/assets.tgz"

scp inventory.yml "root@$adminhost":./ansible/inventory/offline/inventory.yml


echo "$ssh_private_key" > ssh_private_key
chmod 400 ssh_private_key

ssh "root@$adminhost" cat ./ansible/inventory/offline/inventory.yml || true

echo "Running ansible playbook setup_nodes.yml via adminhost ($adminhost)..."
ansible-playbook -i inventory.yml setup_nodes.yml --private-key "ssh_private_key" \
  -e "ansible_ssh_common_args='-o ProxyCommand=\"ssh -W %h:%p -q root@$adminhost -i ssh_private_key\" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'"

# NOTE: Agent is forwarded; so that the adminhost can provision the other boxes
ssh -A "root@$adminhost" "$BIN_DIR/offline-deploy.sh"
