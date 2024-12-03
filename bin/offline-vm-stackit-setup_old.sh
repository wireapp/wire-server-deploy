#!/usr/bin/env bash

set -Eeuo pipefail

msg() {
  echo >&2 -e "${1-}"
}

if [[ $EUID -eq 0 ]]; then
  msg "Please don't run me as root" 1>&2
  exit 1
fi

trap cleanup SIGINT SIGTERM ERR EXIT

usage() {
  cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [--deploy-container name]

Non-interactive script for deploying a standard set of Ubuntu Server containers using LXC.
All containers are created with static IPs from the default LXC bridge (lxdbr0: 10.0.3.0/24).

Available options:
-h, --help                Print this help and exit
-v, --verbose             Print debug info
--deploy-container name   Deploy a single Ubuntu container
EOF
  exit
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
}
die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

parse_params() {
  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose) set -x ;;
    --deploy-container) DEPLOY_SINGLE_CONTAINER=1 ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done
  return 0
}

parse_params "$@"

CONTAINER_NAME=(assethost kubenode1 kubenode2 kubenode3 ansnode1 ansnode2 ansnode3)
CONTAINER_IP=(10.0.3.10 10.0.3.21 10.0.3.22 10.0.3.23 10.0.3.31 10.0.3.32 10.0.3.33)
CONTAINER_RAM=(4096 8192 8192 8192 8192 8192 8192)
CONTAINER_CPU=(2 6 6 6 4 4 4)

if [[ -f "$HOME/.ssh/authorized_keys" && -s "$HOME/.ssh/authorized_keys" ]]; then
  SSH_KEY=$(head -n 1 "$HOME/.ssh/authorized_keys")
else
  read -r -p "No SSH key found; please enter a valid SSH key: " SSH_KEY
fi

msg ""
msg "Including the following SSH Key for container deployment:"
msg "$SSH_KEY"
msg ""

# Ensure the default storage pool exists
msg "Checking storage pool configuration..."
if ! lxc storage list | grep -q "default"; then
  msg "Default storage pool not found. Creating it..."
  lxc storage create default dir
else
  msg "Default storage pool already exists."
fi

# Ensure the default profile has a root device configured
msg "Checking default profile configuration..."
if ! lxc profile show default | grep -q "root"; then
  msg "Root device missing in default profile. Adding it..."
  lxc profile device add default root disk path=/ pool=default
else
  msg "Default profile is correctly configured."
fi

# Ensure the default network exists
msg "Checking network configuration..."
if ! lxc network list | grep -q "lxdbr0"; then
  msg "Default network lxdbr0 not found. Creating it..."
  lxc network create lxdbr0
  lxc network set lxdbr0 ipv4.address 10.0.3.1/24
  lxc network set lxdbr0 ipv4.nat true
  lxc network set lxdbr0 ipv6.address none
else
  msg "Default network lxdbr0 already exists."
fi

create_container() {
  local name=$1
  local ip=$2
  local ram=$3
  local cpu=$4

  msg "Creating container: $name"
  lxc launch ubuntu-daily:jammy "$name"  --storage default

  msg "Configuring container resources..."
  lxc config set "$name" limits.memory "${ram}MB"
  lxc config set "$name" limits.cpu "$cpu"

  msg "Attaching network and configuring static IP: $ip"
  lxc network attach lxdbr0 "$name" eth0
  lxc config device set "$name" eth0 ipv4.address "$ip"

  msg "Creating demo user and adding SSH key..."
  lxc exec "$name" -- bash -c "
    if ! id -u demo > /dev/null 2>&1; then
      adduser --disabled-password --gecos '' demo
      usermod -aG sudo demo
    fi
    mkdir -p /home/demo/.ssh
    echo \"$SSH_KEY\" > /home/demo/.ssh/authorized_keys
    chown -R demo:demo /home/demo/.ssh
    chmod 600 /home/demo/.ssh/authorized_keys
  "

  msg "Starting container..."
  lxc restart "$name"
}

for ((i = 0; i < ${#CONTAINER_NAME[@]}; i++)); do
  if lxc list | grep -q "${CONTAINER_NAME[i]}"; then
    msg "Container ${CONTAINER_NAME[i]} already exists. Skipping..."
    continue
  else
    create_container "${CONTAINER_NAME[i]}" "${CONTAINER_IP[i]}" "${CONTAINER_RAM[i]}" "${CONTAINER_CPU[i]}"
  fi
done