#!/usr/bin/env bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Function to check if image exists and get its name, or load from tar
check_or_load_image() {
    local tar_file="$1"
    local image_pattern="$2"

    # Check if any image matching pattern exists in docker
    local existing_image
    existing_image=$(sudo docker images --format "{{.Repository}}:{{.Tag}}" | grep -F "$image_pattern" | head -1)
    if [[ -n "$existing_image" ]]; then
        echo "$existing_image"
        return 0
    fi

    # If no existing image, load from tar
    if [[ -z "$tar_file" || ! -f "$tar_file" ]]; then
        echo "Tar file does not exist: $tar_file, skipping" >&2
    else
      sudo docker load -i "$tar_file" | awk '{print $3}'
    fi
}

ZAUTH_TAR=$(find "$SCRIPT_DIR/../containers-adminhost" -maxdepth 1 -name "quay.io_wire_zauth_*.tar" -type f | sort | tail -1)

# Get container image names efficiently
ZAUTH_CONTAINER=$(check_or_load_image "$ZAUTH_TAR" "quay.io/wire/zauth") || true
WSD_CONTAINER=$(check_or_load_image "$SCRIPT_DIR/../containers-adminhost/container-wire-server-deploy.tgz" "quay.io/wire/wire-server-deploy") || true

# Export only if ZAUTH_CONTAINER is not empty
[[ -n "$ZAUTH_CONTAINER" ]] && export ZAUTH_CONTAINER

# detect if d should run interactively
d() {
    local docker_flags=""
    # Check if both stdin and stdout are terminals
    # If either of them is not a terminal (piped/redirected), run in detached mode
    if [[ -t 0 ]] && [[ -t 1 ]]; then
        docker_flags="-it"
    fi

    # Run docker with appropriate flags
    sudo docker run --network=host $docker_flags \
    -v "${SSH_AUTH_SOCK:-nonexistent}:/ssh-agent" \
    -e SSH_AUTH_SOCK=/ssh-agent \
    -v "$HOME/.ssh:/root/.ssh" \
    -v "$PWD:/wire-server-deploy" \
    -v "$HOME/.kube:/root/.kube" \
    -v "$HOME/.minikube:$HOME/.minikube" \
    -e KUBECONFIG=/root/.kube/config \
    "$WSD_CONTAINER" "$@"

    return 0
}
