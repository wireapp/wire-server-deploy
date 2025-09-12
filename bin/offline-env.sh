#!/usr/bin/env bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Function to check if image exists and get its name, or load from tar
check_or_load_image() {
    local tar_file="$1"
    local image_pattern="$2"

    # Check if any image matching pattern exists in docker
    local existing_image=$(sudo docker images --format "{{.Repository}}:{{.Tag}}" | grep "$image_pattern" | head -1)
    if [ -n "$existing_image" ]; then
        echo "$existing_image"
        return 0
    fi

    # If no existing image, load from tar
    sudo docker load -i "$tar_file" | awk '{print $3}'
}

# Get container image names efficiently
ZAUTH_CONTAINER=$(check_or_load_image "$SCRIPT_DIR/../containers-adminhost/quay.io_wire_zauth_"*.tar "quay.io/wire/zauth")
WSD_CONTAINER=$(check_or_load_image "$SCRIPT_DIR/../containers-adminhost/container-wire-server-deploy.tgz" "quay.io/wire/wire-server-deploy")

export ZAUTH_CONTAINER

alias d="sudo docker run -it --network=host -v \${SSH_AUTH_SOCK:-nonexistent}:/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent -v \$HOME/.ssh:/root/.ssh -v \$PWD:/wire-server-deploy $WSD_CONTAINER"