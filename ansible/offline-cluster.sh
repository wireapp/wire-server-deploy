#!/usr/bin/env bash

set -eou pipefail

# This invokes certain playbooks to bootstrap a k8s cluster in an offline environment.

# Copies over binaries and debs, serves assets from the asset host, and configures other hosts to fetch debs from it.
ansible-playbook -i ./inventory/offline ./setup-offline-sources.yml

# Run kubespray until docker is installed and runs
ansible-playbook -i ./inventory/offline ./roles-external/kubespray/cluster.yml --tags bastion,bootstrap-os,preinstall,container-engine

# Seed the containers from static/containers to all nodes
# TODO: copy to bastion once, and download from there
ansible-playbook -i ./inventory/offline ./seed-offline-docker.yml

# Run the rest of kubespray
ansible-playbook -i ./inventory/offline ./kubernetes.yml --skip-tags bootstrap-os,preinstall,container-engine
