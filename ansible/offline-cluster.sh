#!/usr/bin/env bash

set -eou pipefail

# This invokes certain playbooks to bootstrap a k8s cluster in an offline environment.

# Copies over binaries and debs, serves assets from the asset host, and configures other hosts to fetch debs from it.
ansible-playbook -i ./inventory/offline ./setup-offline-sources.yml

# Run kubespray until docker is installed and runs
ansible-playbook -i ./inventory/offline ./kubernetes.yml --tags bastion,bootstrap-os,preinstall,container-engine

# install docker on restund role, such that we can seed
ansible-playbook -i ./inventory/offline ./restund.yml --tags docker

# Seed the containers from containers to all nodes
ansible-playbook -i ./inventory/offline ./seed-offline-docker.yml --skip-tags containers-helm

# Run the rest of kubespray
ansible-playbook -i ./inventory/offline ./kubernetes.yml --skip-tags bootstrap-os,preinstall,container-engine

ansible-playbook -i ./inventory/offline ./cassandra.yml

ansible-playbook -i ./inventory/offline ./elasticsearch.yml

ansible-playbook -i ./inventory/offline ./restund.yml

ansible-playbook -i ./inventory/offline ./minio.yml

# Write IPs of external databases; for helm chart rendering
ansible-playbook -i ./inventory/offline helm_external.yml
