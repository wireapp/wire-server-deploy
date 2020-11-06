#!/usr/bin/env bash

set -eou pipefail

# This invokes certain playbooks to bootstrap a k8s cluster in an offline environment.

# Copies over binaries and debs, serves assets from the asset host, and configures other hosts to fetch debs from it.
ansible-playbook -i ./inventory/offline ./setup-offline-sources.yml --skip-tags helm-containers

# Run kubespray until docker is installed and runs
ansible-playbook -i ./inventory/offline ./kubernetes.yml --tags bastion,bootstrap-os,preinstall,container-engine

# Only install docker on restund role, such that we can seed
ansible-playbook -i ./inventory/offline ./restund.yml --tags docker

# Seed the containers from static/containers to all nodes
ansible-playbook -i ./inventory/offline ./seed-offline-docker.yml --tags system-containers,restund

# Run the rest of kubespray
ansible-playbook -i ./inventory/offline ./kubernetes.yml --skip-tags bootstrap-os,preinstall,container-engine

# Copy ~/.kube/config from the first master node
ansible -i ./inventory/offline "kube-master[0]" -m fetch -a  "src=/root/.kube/config dest=kubeconfig flat=yes"

# Edit it to point to localhost:6443
KUBECONFIG=$PWD/kubeconfig kubectl config set clusters.cluster.local.server https://localhost:6443


# Prompt the user to setup a port forward
echo "Please set up a port forward from 6443 to a apiserver node"

# KUBECONFIG=$PWD/kubeconfig kubectl get nodes

