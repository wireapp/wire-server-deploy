#!/usr/bin/env bash

set -eou pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ANSIBLE_DIR="$( cd "$SCRIPT_DIR/../ansible" && pwd )"

set -x

ls $ANSIBLE_DIR/inventory/offline

# Populate the assethost, and prepare to install images from it.
#
# Copy over binaries and debs, serves assets from the asset host, and configure
# other hosts to fetch debs from it.
#
# If this step fails partway, and you know that parts of it completed, the `--skip-tags debs,binaries,containers,containers-helm,containers-other` tags may come in handy.
ansible-playbook -i $ANSIBLE_DIR/inventory/offline/hosts.ini $ANSIBLE_DIR/setup-offline-sources.yml

# Run kubespray until docker is installed and runs. This allows us to preseed the docker containers that
# are part of the offline bundle
ansible-playbook -i $ANSIBLE_DIR/inventory/offline/hosts.ini $ANSIBLE_DIR/kubernetes.yml --tags bastion,bootstrap-os,preinstall,container-engine

# Install docker on the restund nodes
ansible-playbook -i $ANSIBLE_DIR/inventory/offline/hosts.ini $ANSIBLE_DIR/restund.yml --tags docker

# With ctr being installed on all nodes that need it, seed all container images:
ansible-playbook -i $ANSIBLE_DIR/inventory/offline/hosts.ini $ANSIBLE_DIR/seed-offline-containerd.yml

# Install NTP
ansible-playbook -i $ANSIBLE_DIR/inventory/offline/hosts.ini $ANSIBLE_DIR/sync_time.yml -v

# Run the rest of kubespray. This should bootstrap a kubernetes cluster successfully:
ansible-playbook -i $ANSIBLE_DIR/inventory/offline/hosts.ini $ANSIBLE_DIR/kubernetes.yml --skip-tags bootstrap-os,preinstall,container-engine

./bin/fix_default_router.sh

# Deploy all other services which don't run in kubernetes.
ansible-playbook -i $ANSIBLE_DIR/inventory/offline/hosts.ini $ANSIBLE_DIR/cassandra.yml
ansible-playbook -i $ANSIBLE_DIR/inventory/offline/hosts.ini $ANSIBLE_DIR/elasticsearch.yml
ansible-playbook -i $ANSIBLE_DIR/inventory/offline/hosts.ini $ANSIBLE_DIR/restund.yml
ansible-playbook -i $ANSIBLE_DIR/inventory/offline/hosts.ini $ANSIBLE_DIR/minio.yml
ansible-playbook -i $ANSIBLE_DIR/inventory/offline/hosts.ini $ANSIBLE_DIR/rabbitmq.yml
