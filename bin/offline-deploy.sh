#!/usr/bin/env bash

set -euo pipefail


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# HACK: hack to stop ssh from idling the connection. Which it will do if there is no output. And ansible is not verbose enough
(while true; do echo "Still deploying..."; sleep 10; done) &
loop_pid=$!

trap 'kill "$loop_pid"' EXIT

ZAUTH_CONTAINER=$(sudo docker load -i $SCRIPT_DIR/../containers-adminhost/quay.io_wire_zauth_*.tar | awk '{print $3}')
export ZAUTH_CONTAINER

WSD_CONTAINER=$(sudo docker load -i $SCRIPT_DIR/../containers-adminhost/container-wire-server-deploy.tgz | awk '{print $3}')

./bin/offline-secrets.sh

sudo docker run --network=host -v $SSH_AUTH_SOCK:/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent -v $PWD:/wire-server-deploy $WSD_CONTAINER ./bin/offline-cluster.sh
sudo docker run --network=host -v $SSH_AUTH_SOCK:/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent -v $PWD:/wire-server-deploy $WSD_CONTAINER ./bin/offline-helm.sh
