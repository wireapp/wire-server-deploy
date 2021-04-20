#!/usr/bin/env bash

set -eou pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ANSIBLE_DIR="$( cd "$SCRIPT_DIR/../ansible" && pwd )"

ansible-playbook -i $ANSIBLE_DIR/inventory/offline $ANSIBLE_DIR/setup-offline-sources.yml
ansible-playbook -i $ANSIBLE_DIR/inventory/offline $ANSIBLE_DIR/kubernetes.yml --tags bastion,bootstrap-os,preinstall,container-engine
ansible-playbook -i $ANSIBLE_DIR/inventory/offline $ANSIBLE_DIR/restund.yml --tags docker
ansible-playbook -i $ANSIBLE_DIR/inventory/offline $ANSIBLE_DIR/seed-offline-docker.yml
ansible-playbook -i $ANSIBLE_DIR/inventory/offline $ANSIBLE_DIR/kubernetes.yml --skip-tags bootstrap-os,preinstall,container-engine
ansible-playbook -i $ANSIBLE_DIR/inventory/offline $ANSIBLE_DIR/cassandra.yml
ansible-playbook -i $ANSIBLE_DIR/inventory/offline $ANSIBLE_DIR/elasticsearch.yml
ansible-playbook -i $ANSIBLE_DIR/inventory/offline $ANSIBLE_DIR/restund.yml
ansible-playbook -i $ANSIBLE_DIR/inventory/offline $ANSIBLE_DIR/minio.yml
ansible-playbook -i $ANSIBLE_DIR/inventory/offline $ANSIBLE_DIR/helm_external.yml
