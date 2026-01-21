#!/usr/bin/env bash

set -eou pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(cd "$SCRIPT_DIR/../ansible" && pwd)"

set -x

ls $ANSIBLE_DIR/inventory/offline

if [[ -f "$ANSIBLE_DIR/inventory/offline/hosts.ini" ]]; then
  INVENTORY_FILE="$ANSIBLE_DIR/inventory/offline/hosts.ini"
elif [[ -f "$ANSIBLE_DIR/inventory/offline/inventory.yml" ]]; then
  INVENTORY_FILE="$ANSIBLE_DIR/inventory/offline/inventory.yml"
else
  echo "No inventory file in ansible/inventory/offline/. Please supply an $ANSIBLE_DIR/inventory/offline/inventory.yml or $ANSIBLE_DIR/inventory/offline/hosts.ini" >&2
  exit 1
fi

if [[ -f "$ANSIBLE_DIR/inventory/offline/hosts.ini" ]] && [[ -f "$ANSIBLE_DIR/inventory/offline/inventory.yml" ]]; then
  echo "Both hosts.ini and inventory.yml provided in ansible/inventory/offline! Pick only one." >&2
  exit 1
fi

echo "using ansible inventory: $INVENTORY_FILE"

# Populate the assethost, and prepare to install images from it.
#
# Copy over binaries and debs, serves assets from the asset host, and configure
# other hosts to fetch debs from it.
#
# If this step fails partway, and you know that parts of it completed, the `--skip-tags debs,binaries,containers,containers-helm,containers-other` tags may come in handy.
ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/setup-offline-sources.yml"

# Run kubespray until docker is installed and runs. This allows us to preseed the docker containers that
# are part of the offline bundle
ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/kubernetes.yml" --tags bastion,bootstrap-os,preinstall,container-engine

# With ctr being installed on all nodes that need it, seed all container images:
ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/seed-offline-containerd.yml"

# Install NTP
ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/sync_time.yml" -v

# Run the rest of kubespray. This should bootstrap a kubernetes cluster successfully:
# Phase 1: Bootstrap WITHOUT loadbalancer_apiserver so kubeadm uses node IP
# We skip kube-vip to avoid race condition with VIP
ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/kubernetes.yml" \
  --skip-tags bootstrap-os,preinstall,container-engine,multus,kube-vip

# Phase 2: Configure API endpoint (kube-vip or direct node IP)
# Check if kube-vip is enabled in the inventory
INVENTORY_DIR="$(dirname "$INVENTORY_FILE")"

# Check kube_vip_enabled flag from inventory
KUBE_VIP_ENABLED=$(yq eval '.k8s-cluster.vars.kube_vip_enabled // ""' "$INVENTORY_FILE" 2>/dev/null || echo "")
if [[ -z "$KUBE_VIP_ENABLED" ]] || [[ "$KUBE_VIP_ENABLED" = "null" ]]; then
  GROUP_VARS_FILE="$INVENTORY_DIR/group_vars/k8s-cluster/k8s-cluster.yml"
  if [[ -f "$GROUP_VARS_FILE" ]]; then
    KUBE_VIP_ENABLED=$(yq eval '.kube_vip_enabled // ""' "$GROUP_VARS_FILE" 2>/dev/null || echo "")
  fi
fi

if [[ "$KUBE_VIP_ENABLED" = "true" ]]; then
  # ===== kube-vip HA Mode =====
  # Extract VIP address from inventory
  VIP_ADDRESS=$(yq eval '.k8s-cluster.vars.kube_vip_address // ""' "$INVENTORY_FILE" 2>/dev/null || echo "")
  if [[ -z "$VIP_ADDRESS" ]] || [[ "$VIP_ADDRESS" = "null" ]]; then
    GROUP_VARS_FILE="$INVENTORY_DIR/group_vars/k8s-cluster/k8s-cluster.yml"
    if [[ -f "$GROUP_VARS_FILE" ]]; then
      VIP_ADDRESS=$(yq eval '.kube_vip_address // ""' "$GROUP_VARS_FILE" 2>/dev/null || echo "")
    fi
  fi

  if [[ -n "$VIP_ADDRESS" ]] && [[ "$VIP_ADDRESS" != "null" ]]; then
    echo "Deploying kube-vip with VIP: $VIP_ADDRESS"
    ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/kubernetes.yml" \
      --tags kube-vip,client \
      -e "{\"loadbalancer_apiserver\": {\"address\": \"$VIP_ADDRESS\", \"port\": 6443}}" \
      -e "apiserver_loadbalancer_domain_name=$VIP_ADDRESS" \
      -e "loadbalancer_apiserver_localhost=false" \
      -e "{\"supplementary_addresses_in_ssl_keys\": [\"$VIP_ADDRESS\"]}"

    export KUBECONFIG="$ANSIBLE_DIR/inventory/offline/artifacts/admin.conf"
    echo "✓ kube-vip deployed with VIP: $VIP_ADDRESS"
  else
    echo "ERROR: kube_vip_enabled=true but no VIP address found in inventory!" >&2
    exit 1
  fi
else
  # ===== Direct Node IP Mode (No kube-vip) =====
  # Phase 1 already configured kubeconfig with first node IP during cluster bootstrap
  # No additional configuration needed
  echo "kube-vip disabled, using direct node IP from cluster bootstrap"
  export KUBECONFIG="$ANSIBLE_DIR/inventory/offline/artifacts/admin.conf"
  echo "✓ Kubernetes API endpoint configured during Phase 1 bootstrap"
fi

# Deploy all other services which don't run in kubernetes.
ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/cassandra.yml"
ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/elasticsearch.yml"
ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/minio.yml"
ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/postgresql-deploy.yml"

# Uncomment to deploy external RabbitMQ (temporarily commented out until implemented in CD), PS. remote --skip-tags=rabbitmq-external from the next section
#ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/roles/rabbitmq-cluster/tasks/configure_dns.yml"
#ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/rabbitmq.yml"

# create helm values that tell our helm charts what the IP addresses of cassandra, elasticsearch and minio are:
ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/helm_external.yml" --skip-tags=rabbitmq-external
