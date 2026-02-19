#!/usr/bin/env bash
#
# Non-interactive script for deploying the Wire standard set of Ubuntu Server VMs 
# on a single dedicated server using libvirt.
# 
# Script will create VMs with a sudo user "demo" and PW auth disabled.
# All VMs are created with DHCP IPs from default libvirt subnet (192.168.122.0/24). 
# IPs and hostnames are automatically appended to /etc/hosts once VMs receive their addresses.
#
# The script will exit gracefully if VMs already exist.
#
# | hostname  | RAM    | VCPUs | disk space (thin provisioned) |
#  --------------------------------------------------------------
# | assethost | 4 GiB  | 2     | 100 GB                        |
# | kubenode1 | 9 GiB  | 5     | 150 GB                         |
# | kubenode2 | 9 GiB  | 5     | 150 GB                         |
# | kubenode3 | 9 GiB  | 5     | 150 GB                         |
# | datanode1  | 8 GiB | 4     | 100 GB                        |
# | datanode2  | 8 GiB | 4     | 100 GB                        |
# | datanode3  | 8 GiB | 4     | 100 GB                        |
#  --------------------------------------------------------------
# | total     | 55 GiB |  29   | 850 GB                        |

set -Eeuo pipefail

msg() {
  echo >&2 -e "${1-}"
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
}

if [[ $EUID -eq 0 ]]; then
  msg "Please don't run me as root" 1>&2
  exit 1
fi

trap cleanup SIGINT SIGTERM ERR EXIT

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
DEPLOY_DIR="$(cd "$SCRIPT_DIR/../" && pwd)"
NOCLOUD_DIR=$DEPLOY_DIR/nocloud
BASE_IMAGE_DIR="$DEPLOY_DIR/"
BASE_IMAGE="$BASE_IMAGE_DIR/ubuntu-22.04-base.qcow2"
IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"

mkdir -p "$NOCLOUD_DIR"
mkdir -p "$BASE_IMAGE_DIR"

# Download base Ubuntu cloud image if not present
if [ ! -f "$BASE_IMAGE" ]; then
  msg "Downloading Ubuntu 22.04 cloud image to $BASE_IMAGE ..."
  curl -fL -o "$BASE_IMAGE" "$IMAGE_URL" || die "Failed to download Ubuntu cloud image"
  msg "Base image downloaded successfully"
fi

SSH_DIR="$DEPLOY_DIR/ssh"
mkdir -p "$SSH_DIR"

# SSH key paths
SSH_PRIVKEY="$SSH_DIR/id_ed25519"
SSH_PUBKEY="$SSH_DIR/id_ed25519.pub"

# Create SSH keypair if it doesn't exist
if [ ! -f "$SSH_PRIVKEY" ]; then
  msg "Generating SSH keypair in $SSH_DIR..."
  ssh-keygen -t ed25519 -q -N '' -f "$SSH_PRIVKEY"
  msg "SSH keypair generated successfully"
fi

# Check and fix SSH private key permissions
if [ -f "$SSH_PRIVKEY" ]; then
  current_perms=$(stat -c %a "$SSH_PRIVKEY" 2>/dev/null || stat -f %A "$SSH_PRIVKEY" 2>/dev/null)
  if [ "$current_perms" != "400" ]; then
    msg "Fixing SSH private key permissions from $current_perms to 400"
    chmod 400 "$SSH_PRIVKEY"
  fi
fi

# Read the public key
SSHKEY_DEMO=$(cat "$SSH_PUBKEY")

VM_NAME=(assethost kubenode1 kubenode2 kubenode3 datanode1 datanode2 datanode3)
VM_VCPU=(2 5 5 5 4 4 4)
VM_RAM=(4096 9216 9216 9216 8192 8192 8192)
VM_DISK=(100 150 150 150 100 100 100)
VM_NETWORK='wirebox'

# Check if VM_NETWORK exists, if not fall back to 'default'
if ! sudo virsh net-list --all 2>/dev/null | grep -Fq "$VM_NETWORK"; then
  msg "Network $VM_NETWORK not found, switching to default network"
  VM_NETWORK='default'
fi

msg ""
msg "Including the following SSH Keys for VM deployment:"
msg ""
msg "SSH keys stored in: $SSH_DIR"
msg "Public key: $SSHKEY_DEMO"
msg ""


prepare_config() {
  VM_DIR=$NOCLOUD_DIR/${VM_NAME[i]}
  mkdir -p "$VM_DIR"
  
  cat >"$VM_DIR/user-data"<<EOF
#cloud-config
hostname: ${VM_NAME[i]}
fqdn: ${VM_NAME[i]}.local
manage_etc_hosts: true
network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: true
users:
  - name: demo
    groups: sudo
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - $SSHKEY_DEMO
ssh_pwauth: false
disable_root: true
EOF

  cat >"$VM_DIR/meta-data"<<EOF
instance-id: ${VM_NAME[i]}
local-hostname: ${VM_NAME[i]}
EOF

  # Generate cloud-init seed ISO
  cloud-localds "$VM_DIR/seed.iso" "$VM_DIR/user-data" "$VM_DIR/meta-data" 2>/dev/null || \
    die "Failed to create cloud-init seed ISO for ${VM_NAME[i]}"
}

get_vm_ip() {
  local vm_name=$1
  local max_wait=${2:-300}
  local elapsed=0
  
  while [ "$elapsed" -lt "$max_wait" ]; do
    # Get MAC address of VM
    local mac
    mac=$(sudo virsh domiflist "$vm_name" 2>/dev/null | grep -oP '(?<=  )[0-9a-f:]{17}' | head -1)
    
    if [ -n "$mac" ]; then
      # Query DHCP leases for this MAC address
      local ip
      ip=$(sudo virsh net-dhcp-leases "$VM_NETWORK" 2>/dev/null | grep "$mac" | awk '{print $5}' | cut -d'/' -f1)
      
      if [ -n "$ip" ]; then
        echo "$ip"
        return 0
      fi
    fi
    
    sleep 30
    elapsed=$((elapsed + 30))
  done
  
  return 1
}

create_vm () {
  # Check if VM already exists
  if sudo virsh list --all | grep -Fq "${VM_NAME[i]}"; then
    msg "VM ${VM_NAME[i]} already exists, skipping creation"
    return 0
  fi

  prepare_config "${VM_NAME[i]}"

  VM_DISK_PATH="/var/lib/libvirt/images/${VM_NAME[i]}.qcow2"
  SEED_ISO="$NOCLOUD_DIR/${VM_NAME[i]}/seed.iso"

  # Create qcow2 backing file from base image
  sudo qemu-img create -f qcow2 -b "$BASE_IMAGE" -F qcow2 "$VM_DISK_PATH" || \
    die "Failed to create backing file for ${VM_NAME[i]}"

  # Resize backing file to desired size
  sudo qemu-img resize "$VM_DISK_PATH" "${VM_DISK[i]}G" || \
    die "Failed to resize disk for ${VM_NAME[i]}"

  sudo virt-install \
    --name "${VM_NAME[i]}" \
    --ram "${VM_RAM[i]}" \
    --disk "path=$VM_DISK_PATH,format=qcow2,bus=virtio" \
    --disk "path=$SEED_ISO,device=cdrom" \
    --vcpus "${VM_VCPU[i]}" \
    --network "bridge=virbr0,model=virtio" \
    --graphics none \
    --osinfo ubuntu22.04 \
    --noautoconsole \
    --import \
    --console pty,target_type=serial
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
    msg "VCPUs: ""${VM_VCPU[i]}"""
    msg "RAM:   ""${VM_RAM[i]}"" MiB"
    msg "DISK:  ""${VM_DISK[i]}"" GB"
    create_vm "${VM_NAME[i]}"
  fi
done

msg ""
msg "Waiting for VMs to complete cloud-init provisioning..."
msg ""

# Create environment file to store VM IPs
ENV_FILE="$DEPLOY_DIR/.vm-env"
: > "$ENV_FILE"  # Clear the file

for (( i=0; i<${#VM_NAME[@]}; i++ )); do
  # Skip if VM already existed
  if sudo virsh list --all | grep -Fq "${VM_NAME[i]}"; then
    msg ""
    msg "Waiting for ${VM_NAME[i]} to acquire DHCP IP address..."
    
    # Wait for VM to get IP address from DHCP
    if vm_ip=$(get_vm_ip "${VM_NAME[i]}" 120); then
      msg "${VM_NAME[i]} acquired IP: $vm_ip"
      
      # Set environment variable for this VM
      env_var_name="${VM_NAME[i]}_ip"
      export "${env_var_name}=$vm_ip"
      echo "export ${env_var_name}=$vm_ip" >> "$ENV_FILE"
      
      # Update /etc/hosts with the actual DHCP IP
      if grep -Fq "${VM_NAME[i]}" /etc/hosts; then
        msg "Updating /etc/hosts for ${VM_NAME[i]} with IP $vm_ip"
        sudo sed -i -e "/${VM_NAME[i]}/c\\$vm_ip ${VM_NAME[i]}" /etc/hosts
      else
        msg "Writing ${VM_NAME[i]} ($vm_ip) to /etc/hosts"
        echo "$vm_ip ${VM_NAME[i]}" | sudo tee -a /etc/hosts >/dev/null
      fi
      
      # Wait for SSH connectivity
      msg "Waiting for SSH connectivity on ${VM_NAME[i]} ($vm_ip)..."
      max_attempts=10
      attempt=0
      
      while ! ssh -i "$SSH_PRIVKEY" -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
              "demo@$vm_ip" "exit" 2>/dev/null; do
        attempt=$((attempt + 1))
        if [ $attempt -gt $max_attempts ]; then
          msg "WARNING: ${VM_NAME[i]} ($vm_ip) did not become reachable after $max_attempts attempts"
          break
        fi
        sleep 30
      done
      
      # Wait for cloud-init to complete
      if [ $attempt -le $max_attempts ]; then
        msg "Waiting for cloud-init to complete on ${VM_NAME[i]}..."
        ssh -i "$SSH_PRIVKEY" -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            "demo@$vm_ip" "cloud-init status --wait" 2>/dev/null || true
        msg "VM ${VM_NAME[i]} is ready at $vm_ip"
      fi
    else
      msg "ERROR: ${VM_NAME[i]} did not acquire an IP address within timeout period"
    fi
  fi
done

msg ""
msg "Environment variables saved to: $ENV_FILE"
msg "Source with: source $ENV_FILE"
msg "VM IPs:"
grep export "$ENV_FILE" | sed 's/export /  /'
