#!/usr/bin/env bash
set -eou pipefail

ansible-playbook -i ../../../ansible/inventory/offline simulate_offline.yml

(cd ../../../ansible; ./offline-cluster.sh)
