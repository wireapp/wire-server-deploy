#!/usr/bin/env bash

set -eou pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(cd "$SCRIPT_DIR/../ansible" && pwd)"

set -x

ls $ANSIBLE_DIR/inventory/offline

if [ -f "$ANSIBLE_DIR/inventory/offline/hosts.ini" ]; then
  INVENTORY_FILE="$ANSIBLE_DIR/inventory/offline/hosts.ini"
elif [ -f "$ANSIBLE_DIR/inventory/offline/inventory.yml" ]; then
  INVENTORY_FILE="$ANSIBLE_DIR/inventory/offline/inventory.yml"
else
  echo "No inventory file in ansible/inventory/offline/. Please supply an $ANSIBLE_DIR/inventory/offline/inventory.yml or $ANSIBLE_DIR/inventory/offline/hosts.ini"
  exit -1
fi

if [ -f "$ANSIBLE_DIR/inventory/offline/hosts.ini" ] && [ -f "$ANSIBLE_DIR/inventory/offline/inventory.yml" ]; then
  echo "Both hosts.ini and inventory.yml provided in ansible/inventory/offline! Pick only one."
  exit -1
fi

echo "using ansible inventory: $INVENTORY_FILE"

# Populate the assethost, and prepare to install images from it.
#
# Copy over binaries and debs, serves assets from the asset host, and configure
# other hosts to fetch debs from it.
#
# If this step fails partway, and you know that parts of it completed, the `--skip-tags debs,binaries,containers,containers-helm,containers-other` tags may come in handy.
ansible-playbook -i $INVENTORY_FILE $ANSIBLE_DIR/setup-offline-sources.yml

# Run kubespray until docker is installed and runs. This allows us to preseed the docker containers that
# are part of the offline bundle
ansible-playbook -i $INVENTORY_FILE $ANSIBLE_DIR/kubernetes.yml --tags bastion,bootstrap-os,preinstall,container-engine

# With ctr being installed on all nodes that need it, seed all container images:
ansible-playbook -i $INVENTORY_FILE $ANSIBLE_DIR/seed-offline-containerd.yml

# Install NTP
ansible-playbook -i $INVENTORY_FILE $ANSIBLE_DIR/sync_time.yml -v

# Run the rest of kubespray. This should bootstrap a kubernetes cluster successfully:
# Phase 1: Bootstrap WITHOUT loadbalancer_apiserver so kubeadm uses node IP
# We skip kube-vip to avoid race condition with VIP
ansible-playbook -i $INVENTORY_FILE $ANSIBLE_DIR/kubernetes.yml \
  --skip-tags bootstrap-os,preinstall,container-engine,multus,kube-vip

# Phase 2: Deploy kube-vip AND configure loadbalancer_apiserver
# Now we define loadbalancer_apiserver via -e so kubeconfig gets updated to use VIP
# Extract VIP from inventory if defined, otherwise use a calculated value
# Handle different inventory formats by trying both paths:
#   1. YAML inventory with embedded vars: ."k8s-cluster".vars.kube_vip_address
#   2. INI inventory with group_vars: group_vars/k8s-cluster/k8s-cluster.yml
INVENTORY_DIR="$(dirname "$INVENTORY_FILE")"

# Try to extract VIP from YAML inventory first (Terraform-generated format)
VIP_ADDRESS=$(yq eval '."k8s-cluster".vars.kube_vip_address // ""' "$INVENTORY_FILE" 2>/dev/null || echo "")

# If not found, try group_vars file (static INI format)
if [ -z "$VIP_ADDRESS" ] || [ "$VIP_ADDRESS" = "null" ]; then
  GROUP_VARS_FILE="$INVENTORY_DIR/group_vars/k8s-cluster/k8s-cluster.yml"
  if [ -f "$GROUP_VARS_FILE" ]; then
    VIP_ADDRESS=$(yq eval '.kube_vip_address // ""' "$GROUP_VARS_FILE" 2>/dev/null || echo "")
  fi
fi

if [ -n "$VIP_ADDRESS" ] && [ "$VIP_ADDRESS" != "null" ]; then
  echo "Deploying kube-vip with VIP: $VIP_ADDRESS"
  ansible-playbook -i $INVENTORY_FILE $ANSIBLE_DIR/kubernetes.yml \
    --tags kube-vip,client \
    -e "{\"loadbalancer_apiserver\": {\"address\": \"$VIP_ADDRESS\", \"port\": 6443}}" \
    -e "apiserver_loadbalancer_domain_name=$VIP_ADDRESS" \
    -e "loadbalancer_apiserver_localhost=false" \
    -e "{\"supplementary_addresses_in_ssl_keys\": [\"$VIP_ADDRESS\"]}"

  # ===== Configure VIP routing (if needed) =====
  # In some cloud environments, the adminhost cannot reach the VIP via ARP due to gateway routing.
  # Add a static route to make VIP reachable from adminhost for kubectl commands.
  echo "Checking if VIP routing configuration is needed..."

  # Test if VIP is reachable
  if ! timeout 2 bash -c "cat < /dev/null > /dev/tcp/$VIP_ADDRESS/6443" 2>/dev/null; then
    echo "VIP $VIP_ADDRESS is not reachable from adminhost, configuring static route..."

    # Get VIP interface and first kubenode IP from inventory
    VIP_INTERFACE=$(yq eval '.[\"k8s-cluster\"].vars.kube_vip_interface // ""' "$INVENTORY_FILE" 2>/dev/null)
    FIRST_KUBENODE=$(yq eval '.["kube-node"].hosts | keys | .[0]' "$INVENTORY_FILE" 2>/dev/null)
    FIRST_KUBENODE_IP=$(yq eval ".all.hosts.\"$FIRST_KUBENODE\".ip" "$INVENTORY_FILE" 2>/dev/null)

    # Auto-detect interface if not specified in inventory
    if [ -z "$VIP_INTERFACE" ] || [ "$VIP_INTERFACE" = "null" ]; then
      echo "⚠ VIP interface not found in inventory, attempting auto-detection..."
      # Find interface with route to first kubenode
      VIP_INTERFACE=$(ip route get "$FIRST_KUBENODE_IP" 2>/dev/null | grep -oP 'dev \K\S+' | head -1)
    fi

    if [ -n "$FIRST_KUBENODE_IP" ] && [ "$FIRST_KUBENODE_IP" != "null" ] && [ -n "$VIP_INTERFACE" ]; then
      echo "Adding route: $VIP_ADDRESS via $FIRST_KUBENODE_IP dev $VIP_INTERFACE"
      ip route add "$VIP_ADDRESS/32" via "$FIRST_KUBENODE_IP" dev "$VIP_INTERFACE" 2>/dev/null || true

      # Verify route was added
      if ip route show | grep -q "$VIP_ADDRESS"; then
        echo "✓ Static route configured successfully"

        # Test connectivity again
        if timeout 2 bash -c "cat < /dev/null > /dev/tcp/$VIP_ADDRESS/6443" 2>/dev/null; then
          echo "✓ VIP $VIP_ADDRESS:6443 is now reachable!"
        else
          echo "⚠ WARNING: VIP still not reachable after adding route"
        fi
      else
        echo "⚠ WARNING: Failed to add static route"
      fi
    else
      echo "⚠ WARNING: Could not determine first kubenode IP from inventory"
    fi
  else
    echo "✓ VIP $VIP_ADDRESS:6443 is already reachable, no routing changes needed"
  fi

else
  echo "No VIP configured, skipping kube-vip deployment"

  # Still export KUBECONFIG for nginx localhost load balancer
  export KUBECONFIG="$ANSIBLE_DIR/inventory/offline/artifacts/admin.conf"
  echo "Exported KUBECONFIG=$KUBECONFIG (using nginx localhost load balancer)"
fi

# Deploy all other services which don't run in kubernetes.
ansible-playbook -i $INVENTORY_FILE $ANSIBLE_DIR/cassandra.yml
ansible-playbook -i $INVENTORY_FILE $ANSIBLE_DIR/elasticsearch.yml
ansible-playbook -i $INVENTORY_FILE $ANSIBLE_DIR/minio.yml
ansible-playbook -i $INVENTORY_FILE $ANSIBLE_DIR/postgresql-deploy.yml

# Uncomment to deploy external RabbitMQ (temporarily commented out until implemented in CD), PS. remote --skip-tags=rabbitmq-external from the next section
#ansible-playbook -i $INVENTORY_FILE $ANSIBLE_DIR/roles/rabbitmq-cluster/tasks/configure_dns.yml
#ansible-playbook -i $INVENTORY_FILE $ANSIBLE_DIR/rabbitmq.yml

# create helm values that tell our helm charts what the IP addresses of cassandra, elasticsearch and minio are:
ansible-playbook -i $INVENTORY_FILE $ANSIBLE_DIR/helm_external.yml --skip-tags=rabbitmq-external
