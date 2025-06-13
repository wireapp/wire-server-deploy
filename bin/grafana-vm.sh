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

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  pkill -f "http.server" || true
  rm -r "$DEPLOY_DIR"/nocloud/* 2>/dev/null || true
}

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
DEPLOY_DIR="$(cd "$SCRIPT_DIR/../" && pwd)"
NOCLOUD_DIR=$DEPLOY_DIR/nocloud

if [ ! -d "$NOCLOUD_DIR" ]; then
  mkdir -p "$NOCLOUD_DIR"
fi

VM_NAME="grafananode"
VM_IP="192.168.122.100"
VM_VCPU=4
VM_RAM=8192
VM_DISK=100

while grep -Fq "$VM_IP" /etc/hosts; do
  VM_IP="192.168.122.$(shuf -i100-240 -n1)"
done

if [[ -f "$HOME"/.ssh/authorized_keys && -s "$HOME"/.ssh/authorized_keys ]]; then
  SSHKEY_HUMAN=$(head -n 1 ~/.ssh/authorized_keys)
else
  read -r -p "No local SSH keys for current user $USER found; please enter a valid key now: " SSHKEY_HUMAN
fi

if [[ -f "$HOME"/.ssh/id_ed25519 && -f "$HOME"/.ssh/id_ed25519.pub ]]; then
  SSHKEY_DEMO=$(cat "$HOME"/.ssh/id_ed25519.pub)
elif [[ -f "$HOME"/.ssh/id_ed25519 ]]; then
  # Public key missing, generate it from private key
  ssh-keygen -y -f "$HOME"/.ssh/id_ed25519 > "$HOME"/.ssh/id_ed25519.pub
  SSHKEY_DEMO=$(cat "$HOME"/.ssh/id_ed25519.pub)
else
  ssh-keygen -t ed25519 -q -N '' -f "$HOME"/.ssh/id_ed25519
  SSHKEY_DEMO=$(cat "$HOME"/.ssh/id_ed25519.pub)
fi

msg ""
msg "Including the following SSH Keys for VM deployment:"
msg "Existing key from ~/.ssh/authorized_keys: $SSHKEY_HUMAN"
msg "Local keypair key from ~/.ssh/id_ed25519: $SSHKEY_DEMO"
msg ""

nohup python3 -m http.server 3003 -d "$NOCLOUD_DIR" </dev/null >/dev/null 2>&1 &

prepare_config() {
  VM_DIR=$NOCLOUD_DIR/$VM_NAME
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
        addresses: [$VM_IP/24]
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
    hostname: $VM_NAME
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
  prepare_config

  sudo virt-install \
    --name "$VM_NAME" \
    --ram "$VM_RAM" \
    --disk path=/var/lib/libvirt/images/"$VM_NAME".qcow2,size="$VM_DISK" \
    --vcpus "$VM_VCPU" \
    --network bridge=virbr0 \
    --graphics none \
    --osinfo detect=on,require=off \
    --noautoconsole \
    --location "$DEPLOY_DIR"/ubuntu.iso,kernel=casper/vmlinuz,initrd=casper/initrd \
    --extra-args "console=ttyS0,115200n8 autoinstall ds=nocloud-net;s=http://192.168.122.1:3003/$VM_NAME"
}

if sudo virsh list --all | grep -Fq "$VM_NAME"; then
  msg ""
  msg "ATTENTION - VM $VM_NAME already exists"
  msg ""
  exit 0
else
  set -u
  msg ""
  msg "Creating VM $VM_NAME ..."
  msg "IP:    $VM_IP"
  msg "VCPUs: $VM_VCPU"
  msg "RAM:   $VM_RAM MiB"
  msg "DISK:  $VM_DISK GB"
  create_vm
  if grep -Fq "$VM_NAME" /etc/hosts; then
    msg ""
    msg "Updating existing record in /etc/hosts for $VM_NAME with IP $VM_IP"
    sudo sed -i -e "/$VM_NAME/c\\$VM_IP $VM_NAME" /etc/hosts
  else
    msg ""
    msg "Writing IP and hostname to /etc/hosts ..."
    echo "$VM_IP $VM_NAME" | sudo tee -a /etc/hosts
    msg ""
  fi
  sleep 20
fi

while sudo virsh list --state-running --name | grep -Fxq "$VM_NAME"; do
  sleep 20
  msg "INFO: $VM_NAME deployment still in progress ..."
done