#!/usr/bin/env bash


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ZAUTH_CONTAINER=$(sudo docker load -i $SCRIPT_DIR/../containers-adminhost/quay.io_wire_zauth_*.tar | awk '{print $3}')
export ZAUTH_CONTAINER

WSD_CONTAINER=$(sudo docker load -i $SCRIPT_DIR/../containers-adminhost/container-wire-server-deploy.tgz | awk '{print $3}')

alias d="sudo docker run -it -v --network=host -v $SSH_AUTH_SOCK:/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent $HOME/.ssh:/root/.ssh -v $PWD:/wire-server-deploy $WSD_CONTAINER"
