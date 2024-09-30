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
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [--deploy-vm vmname]

Non-interactive script for deploying the Wire standard set of Ubuntu Server VMs on a single dedicated server using libvirt.
Script will create VMs with a sudo user "demo" and PW auth disabled.

All VMs are created with static IPs from default libvirt subnet (192.168.122.0/24). IPs and hostnames are appended to /etc/hosts for convenience.

For SSH access, it'll use two keys:
 * The first key found in ~/.ssh/authorized_keys. Will ask interactively if no key can be found (and accept any input, so be careful).
 * The key found in ~/.ssh/id_ed25519.pub. Will silently generate a new key pair if none can be found.

The script will exit gracefully if VMs already exist.

Default mode with no arguments creates seven libvirt VMs using cloud-init:

 | hostname  | IP             | RAM      | VCPUs | disk space (thin provisioned) |
  -------------------------------------------------------------------------------
 | assethost | 192.168.122.10 | 4096 MiB | 2     | 100 GB                        |
 | kubenode1 | 192.168.122.21 | 8192 MiB | 6     | 100 GB                        |
 | kubenode2 | 192.168.122.22 | 8192 MiB | 6     | 100 GB                        |
 | kubenode3 | 192.168.122.23 | 8192 MiB | 6     | 100 GB                        |
 | ansnode1  | 192.168.122.31 | 8192 MiB | 4     | 350 GB                        |
 | ansnode2  | 192.168.122.32 | 8192 MiB | 4     | 350 GB                        |
 | ansnode3  | 192.168.122.33 | 8192 MiB | 4     | 350 GB                        |

For single VM deployment ("--deploy-vm" flag) a static IP is chosen randomly from .100 to .240 range.
If an IP from that range already exists in /etc/hosts, the shuffle will reiterate until an unused IP is found in order to avoid collisions.

Single VM deployment will create a VM with the following resoures (can be editied in the script prior execution):

 | hostname             | IP                        | RAM      | VCPUs | disk space (thin provisioned) |
  ------------------------------------------------------------------------------------------------------
 | (argument from flag) | (range from .100 to .240) | 8192 MiB | 4     | 100 GB                        |

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
  rm -r "$DEPLOY_DIR"/nocloud/* 2>/dev/null
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
  VM_NAME=("$2")
  VM_IP=("192.168.122.$(shuf -i100-240 -n1)")
  VM_VCPU=(4)
  VM_RAM=(8192)
  VM_DISK=(100)
  while grep -Fq "${VM_IP[0]}" /etc/hosts; do
    VM_IP=("192.168.122.$(shuf -i100-240 -n1)")
  done
else
  VM_NAME=(assethost kubenode1 kubenode2 kubenode3 ansnode1 ansnode2 ansnode3)
  VM_IP=(192.168.122.10 192.168.122.21 192.168.122.22 192.168.122.23 192.168.122.31 192.168.122.32 192.168.122.33)
  VM_VCPU=(2 6 6 6 4 4 4)
  VM_RAM=(4096 8192 8192 8192 8192 8192 8192)
  VM_DISK=(100 100 100 100 100 100 100)
fi

if [[ -f "$HOME"/.ssh/authorized_keys && -s "$HOME"/.ssh/authorized_keys ]]; then
  SSHKEY_HUMAN=$(head -n 1 ~/.ssh/authorized_keys)
else
  read -r -p "No local SSH keys for current user ""$USER"" found; please enter a vaild key now: " SSHKEY_HUMAN
fi

if [[ -f "$HOME"/.ssh/id_ed25519 ]]; then
  SSHKEY_DEMO=$(cat "$HOME"/.ssh/id_ed25519.pub)
else
  ssh-keygen -t ed25519 -q -N '' -f "$HOME"/.ssh/id_ed25519
  SSHKEY_DEMO=$(cat "$HOME"/.ssh/id_ed25519.pub)
fi

msg ""
msg "Including the following SSH Keys for VM deployment:"
msg ""
msg "Existing key from ~/.ssh/authorized_keys: ""$SSHKEY_HUMAN"""
msg "Local keypair key from ~/.ssh/id_ed25519: ""$SSHKEY_DEMO"""
msg ""

nohup python3 -m http.server 3003 -d "$NOCLOUD_DIR" </dev/null >/dev/null 2>&1 &

prepare_config() {
  VM_DIR=$NOCLOUD_DIR/${VM_NAME[i]}
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
        dhcp4: no
        addresses: [${VM_IP[i]}/24]
        nameservers:
          addresses: ['192.168.122.1']
        routes:
          - to: default
            via: 192.168.122.1
  storage:
    layout:
      sizing-policy: all
      name: lvm
      match:
        path: /dev/vda
        size: largest
  ssh:
    allow-pw: false
    install-server: true
  apt:
    fallback: offline-install
  user-data:
    hostname: ${VM_NAME[i]}
    users:
    - default
    - name: demo
      groups: sudo
      sudo: ALL=(ALL) NOPASSWD:ALL
      shell: /bin/bash
      ssh_authorized_keys: 
        - $SSHKEY_HUMAN
        - $SSHKEY_DEMO
EOF
}

create_vm () {
  prepare_config "${VM_NAME[i]}"

  sudo virt-install \
    --name "${VM_NAME[i]}" \
    --ram "${VM_RAM[i]}" \
    --disk path=/var/lib/libvirt/images/"${VM_NAME[i]}".qcow2,size="${VM_DISK[i]}" \
    --vcpus "${VM_VCPU[i]}" \
    --network bridge=virbr0 \
    --graphics none \
    --osinfo detect=on,require=off \
    --noautoconsole \
    --location "$DEPLOY_DIR"/ubuntu.iso,kernel=casper/vmlinuz,initrd=casper/initrd \
    --extra-args "console=ttyS0,115200n8 autoinstall ds=nocloud-net;s=http://192.168.122.1:3003/${VM_NAME[i]}"
}

for (( i=0; i<${#VM_NAME[@]}; i++ )); do
  if sudo virsh list --all | grep -Fq "${VM_NAME[i]}"; then
    msg ""
    msg "ATTENTION - VM ""${VM_NAME[i]}"" already exists"
    msg ""
    continue
  else
    set -u
    msg ""
    msg "Creating VM ""${VM_NAME[i]}"" ..."
    msg "IP:    ""${VM_IP[i]}"""
    msg "VCPUs: ""${VM_VCPU[i]}"""
    msg "RAM:   ""${VM_RAM[i]}"" MiB"
    msg "DISK:  ""${VM_DISK[i]}"" GB"
    create_vm "${VM_NAME[i]}"
    if grep -Fq "${VM_NAME[i]}" /etc/hosts; then
      msg ""
      msg "Updating existing record in /etc/hosts for ""${VM_NAME[i]}"" with IP ""${VM_IP[i]}"""
      sudo sed -i -e "/${VM_NAME[i]}/c\\${VM_IP[i]} ${VM_NAME[i]}" /etc/hosts
    else
      msg ""
      msg "Writing IP and hostname to /etc/hosts ..."
      echo """${VM_IP[i]}"" ""${VM_NAME[i]}""" | sudo tee -a /etc/hosts
      msg ""
    fi
    sleep 20
  fi
done
