#!/usr/bin/env bash

set -euo pipefail

function cleanup {
  (cd terraform/examples/wire-server-deploy-offline-hetzner ; terraform destroy -auto-approve)
  echo done
}
trap cleanup EXIT

(cd terraform/examples/wire-server-deploy-offline-hetzner ; terraform init ; terraform apply -auto-approve )
adminhost=$(cd terraform/examples/wire-server-deploy-offline-hetzner ; terraform output adminhost)
ssh_private_key=$(cd terraform/examples/wire-server-deploy-offline-hetzner ; terraform output ssh_private_key)

eval `ssh-agent`
ssh-add - <<< "$ssh_private_key"

ssh -oStrictHostKeyChecking=accept-new -oConnectionAttempts=10 "root@$adminhost" tar xzv < ./assets.tgz

(cd terraform/examples/wire-server-deploy-offline-hetzner; terraform output -json static-inventory)| ssh "root@$adminhost" tee ./ansible/inventory/offline/inventory.yml

# NOTE: Agent is forwarded; so that the adminhost can provision the other boxes
ssh -A "root@$adminhost" ./bin/offline-deploy.sh



