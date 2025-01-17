#!/usr/bin/env bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ZAUTH_CONTAINER=$(sudo docker load -i "$SCRIPT_DIR"/../containers-adminhost/quay.io_wire_zauth_*.tar | awk '{print $3}')
export ZAUTH_CONTAINER

WSD_CONTAINER=$(sudo docker load -i "$SCRIPT_DIR"/../containers-adminhost/container-wire-server-deploy.tgz | awk '{print $3}')

alias d="sudo docker run -it --network=host \
    -v \${SSH_AUTH_SOCK:-nonexistent}:/ssh-agent \
    -e SSH_AUTH_SOCK=/ssh-agent \
    -v \$HOME/.ssh:/root/.ssh \
    -v \$PWD:/wire-server-deploy \
    -v /home/ubuntu/.kube:/root/.kube \
    -v /home/ubuntu/.minikube:/home/ubuntu/.minikube \
    -e KUBECONFIG=/root/.kube/config \
    \$WSD_CONTAINER"