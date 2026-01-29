#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# HACK: hack to stop ssh from idling the connection. Which it will do if there is no output. And ansible is not verbose enough
(while true; do echo "Still deploying..."; sleep 10; done) &
loop_pid=$!

trap 'kill "$loop_pid"' EXIT

# Load ZAUTH container only if not already present
if ! sudo docker images | grep -q "wire/zauth"; then
    echo "Loading ZAUTH container..."
    ZAUTH_CONTAINER=$(sudo docker load -i $SCRIPT_DIR/../containers-adminhost/quay.io_wire_zauth_*.tar | awk '{print $3}')
else
    echo "ZAUTH container already loaded, skipping..."
    ZAUTH_CONTAINER=$(sudo docker images --format "{{.Repository}}:{{.Tag}}" | grep "wire/zauth" | head -1)
fi
export ZAUTH_CONTAINER

# Load WSD container only if not already present
if ! sudo docker images | grep -q "wire-server-deploy"; then
    echo "Loading WSD container..."
    WSD_CONTAINER=$(sudo docker load -i $SCRIPT_DIR/../containers-adminhost/container-wire-server-deploy.tgz | awk '{print $3}')
else
    echo "WSD container already loaded, skipping..."
    WSD_CONTAINER=$(sudo docker images --format "{{.Repository}}:{{.Tag}}" | grep "wire-server-deploy" | head -1)
fi

#  Create wire secrets
./bin/offline-secrets.sh

# Build docker run command with conditional SSH_AUTH_SOCK mounting
DOCKER_RUN_BASE="sudo docker run --network=host -v $PWD:/wire-server-deploy"
SSH_MOUNT=""
if [ -n "${SSH_AUTH_SOCK:-}" ]; then
    SSH_MOUNT="-v $SSH_AUTH_SOCK:/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent"
fi

$DOCKER_RUN_BASE $SSH_MOUNT $WSD_CONTAINER ./bin/offline-cluster.sh

# Sync PostgreSQL password from K8s secret to secrets.yaml
echo "Syncing PostgreSQL password from Kubernetes secret..."
sudo docker run --network=host -v $PWD:/wire-server-deploy $WSD_CONTAINER ./bin/sync-k8s-secret-to-wire-secrets.sh \
  wire-postgresql-external-secret \
  password \
  values/wire-server/secrets.yaml \
  .brig.secrets.pgPassword \
  .galley.secrets.pgPassword \
  .spar.secrets.pgPassword \
  .gundeck.secrets.pgPassword


sudo docker run --network=host -v $PWD:/wire-server-deploy $WSD_CONTAINER ./bin/offline-helm.sh
