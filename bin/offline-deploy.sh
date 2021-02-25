#!/usr/bin/env bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ZAUTH_CONTAINER=$(sudo docker load -i $SCRIPT_DIR/../containers-adminhost/quay.io_wire_zauth_*.tar | awk '{print $3}')
export ZAUTH_CONTAINER

WSD_CONTAINER=$(sudo docker load -i $SCRIPT_DIR/../containers-adminhost/container-wire-server-deploy.tgz | awk '{print $3}')

sudo docker run -it --network=host -v $HOME/.ssh:/root/.ssh -v $PWD:/wire-server-deploy $WSD_CONTAINER ./bin/offline-cluster.sh
