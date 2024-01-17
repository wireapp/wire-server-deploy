#!/usr/bin/env bash

set -Eeuo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "Please don't run me as root" 1>&2
  exit 1
fi

trap cleanup SIGINT SIGTERM ERR EXIT

usage() {
  cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [--deploy-vm vmname]

Non-interactive script for deploying standard set of Ubuntu Server VMs on a single dedicated Hetzner server.
Script will create VMs with a sudo user "demo" and PW auth disabled.
For SSH access, it'll use the 1st key found in the local user's .ssh/authorized_keys.
If no key can be found, it will interactively ask for a key (and accept any input, so be careful).

Default mode with no arguments creates seven libvirt VMs using cloud-init:
 * assethost
 * kubenode1
 * kubenode2
 * kubenode3
 * ansnode1
 * ansnode2
 * ansnode3

Available options:
-h, --help          Print this help and exit
-v, --verbose       Print script debug info
--deploy-vm vmname  Deploys a single Ubuntu VM
EOF
  exit
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  pkill -f "http.server"
  rm -rf "$DEPLOY_DIR"/nocloud/*
}

msg() {
  echo >&2 -e "${1-}"
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
    --deploy-vm) DEPLOY_SINGLE_VM=1 ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done
  return 0
}

parse_params "$@"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
DEPLOY_DIR="$(cd "$SCRIPT_DIR/../" && pwd)"
NOCLOUD_DIR=$DEPLOY_DIR/nocloud

if [ ! -d "$NOCLOUD_DIR" ]; then
  mkdir -p "$NOCLOUD_DIR"
fi

if [[ -n "${DEPLOY_SINGLE_VM-}" ]]; then
  VM_NAME="$2"
else
  VM_NAME="assethost kubenode1 kubenode2 kubenode3 ansnode1 ansnode2 ansnode3"
fi

nohup python3 -m http.server 3003 -d "$NOCLOUD_DIR" &

if [[ -f ~/.ssh/authorized_keys && -s ~/.ssh/authorized_keys ]]; then
  SSHKEY=$(head -n 1 ~/.ssh/authorized_keys)
  echo "Including local SSH key ""$SSHKEY"" for VM deployment"
else
  read -r -p "No local SSH keys for current user ""$USER"" found; please enter a key now: " SSHKEY
fi

prepare_config() {
  VM_DIR=$NOCLOUD_DIR/$VM
  mkdir -p "$VM_DIR"
  touch "$VM_DIR"/{vendor-data,meta-data}
  cat >"$VM_DIR/user-data"<<EOF
#cloud-config
autoinstall:
  version: 1
  id: ubuntu-server-minimized
  network:
    version: 2
    ethernets:
      enp1s0:
        dhcp4: yes
  ssh:
    allow-pw: false
    install-server: true
  apt:
    fallback: offline-install
  user-data:
    hostname: $VM
    users:
    - default
    - name: demo
      groups: sudo
      sudo: ALL=(ALL) NOPASSWD:ALL
      shell: /bin/bash
      ssh_authorized_keys: 
        - $SSHKEY
EOF
}

create_vm () {
  prepare_config "$VM"

  sudo virt-install \
    --name "$VM" \
    --ram 8192 \
    --disk path=/var/lib/libvirt/images/"$VM".qcow2,size=100  \
    --vcpus 4 \
    --network bridge=virbr0 \
    --graphics none \
    --osinfo detect=on,require=off \
    --noautoconsole \
    --location "$DEPLOY_DIR"/ubuntu.iso,kernel=casper/vmlinuz,initrd=casper/initrd \
    --extra-args "console=ttyS0,115200n8 autoinstall ds=nocloud-net;s=http://192.168.122.1:3003/$VM"
}

for VM in $VM_NAME; do
  set -u
  msg "Creating VM $VM ..."
  create_vm "$VM"
  sleep 20
done
