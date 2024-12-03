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
All containers are created with static IPs assigned by DHCP from the `virbr0` bridge.

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
    --deploy-container) ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done
  return 0
}

parse_params "$@"

CONTAINER_NAME=(assethost kubenode1 kubenode2 kubenode3 ansnode1 ansnode2 ansnode3)
CONTAINER_IP=(192.168.122.10 192.168.122.21 192.168.122.22 192.168.122.23 192.168.122.31 192.168.122.32 192.168.122.33)
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

# Use virbr0 for network
msg "Using virbr0 for container networking..."

create_container() {
  local name=$1
  local ip=$2
  local ram=$3
  local cpu=$4

  msg "Creating container: $name"
  lxc launch ubuntu-daily:jammy "$name" --storage default

  msg "Configuring container resources..."
  lxc config set "$name" limits.memory "${ram}MB"
  lxc config set "$name" limits.cpu "$cpu"

  msg "Attaching network and configuring IP via DHCP..."
  lxc network attach virbr0 "$name" eth0

  msg "Configuring static IP for $name..."
  lxc exec "$name" -- bash -c "
    echo 'network:
      version: 2
      ethernets:
        eth0:
          dhcp4: no
          addresses:
            - $ip/24
          gateway4: 192.168.122.1
          nameservers:
            addresses:
              - 8.8.8.8
              - 8.8.4.4
    ' > /etc/netplan/01-netcfg.yaml
    netplan apply
  "

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
