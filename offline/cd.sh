#!/usr/bin/env bash

set -eou pipefail

function cleanup {
  (cd terraform/examples/wire-server-deploy-offline-hetzner ; terraform destroy -auto-approve)
  echo done
}
trap cleanup EXIT

(cd terraform/examples/wire-server-deploy-offline-hetzner ; terraform init ; terraform apply -auto-approve )
adminhost=$(cd terraform/examples/wire-server-deploy-offline-hetzner ; terraform output adminhost)
ssh "root@$adminhost" tar xzv < ./assets.tgz
(cd terraform/examples/wire-server-deploy-offline-hetzner; terraform output -json static-inventory)| ssh "root@$adminhost" tee ./wire-server-deploy/assets/inventory/offline/inventory.yml


ssh "root@$adminhost" ./bin/offline-deploy.sh



