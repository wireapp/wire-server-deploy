#!/usr/bin/env bash

set -euo pipefail

CD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${CD_DIR}/../terraform/examples/wiab-staging-hetzner"
VALUES_DIR="${CD_DIR}/../values"
TF_VARS_FILE="${TF_DIR}/retry-selection.auto.tfvars.json"
COMMIT_HASH="${GITHUB_SHA}"
ARTIFACT="wire-server-deploy-static-${COMMIT_HASH}"

# Retry matrix
LOCATIONS=("hel1" "nbg1" "fsn1")
SMALL_SERVER_TYPES=("cpx22" "cpx32" "cpx42")
MEDIUM_SERVER_TYPES=("cpx42" "cpx52" "cpx62")

# Retry configuration
RETRY_DELAY=30
APPLY_TIMEOUT_SECONDS=300

echo "Wire Offline Deployment with Retry Logic"
echo "========================================"

function cleanup {
  (cd "$TF_DIR" && terraform destroy -auto-approve)
  echo "Cleanup completed"
}
trap cleanup EXIT

function persist_terraform_vars {
        local location="$1"
        local small_server_type="$2"
        local medium_server_type="$3"

        printf '{\n  "location": "%s",\n  "small_server_type": "%s",\n  "medium_server_type": "%s"\n}\n' \
                "$location" \
                "$small_server_type" \
                "$medium_server_type" > "$TF_VARS_FILE"
}

cd "$TF_DIR"
terraform init

if ! command -v timeout >/dev/null 2>&1; then
    echo "The 'timeout' command is required but not installed"
    exit 1
fi

if [[ ${#SMALL_SERVER_TYPES[@]} -ne ${#MEDIUM_SERVER_TYPES[@]} ]]; then
    echo "Small and medium server type retry lists must have the same length"
    exit 1
fi

if [[ ${#LOCATIONS[@]} -eq 0 || ${#SMALL_SERVER_TYPES[@]} -eq 0 ]]; then
    echo "No location or server type preferences configured in the retry matrix"
    exit 1
fi

location_count=${#LOCATIONS[@]}
server_type_count=${#SMALL_SERVER_TYPES[@]}
MAX_RETRIES=$((location_count * server_type_count))

echo "Retry plan: ${location_count} locations x ${server_type_count} server type pairs = ${MAX_RETRIES} attempts"

# Retry loop for terraform apply
echo "Starting deployment with automatic retry on resource unavailability..."
attempt=1
deployment_succeeded=false

for server_type_index in $(seq 0 $((server_type_count - 1))); do
    for location_index in $(seq 0 $((location_count - 1))); do
        attempt_location="${LOCATIONS[$location_index]}"
        attempt_small_server_type="${SMALL_SERVER_TYPES[$server_type_index]}"
        attempt_medium_server_type="${MEDIUM_SERVER_TYPES[$server_type_index]}"

        persist_terraform_vars "$attempt_location" "$attempt_small_server_type" "$attempt_medium_server_type"


        echo ""
        echo "Deployment attempt $attempt of $MAX_RETRIES"
        echo "   -> location=${attempt_location}, small=${attempt_small_server_type}, medium=${attempt_medium_server_type}"
        date

        if timeout "${APPLY_TIMEOUT_SECONDS}s" terraform apply -auto-approve; then
            echo "Infrastructure deployment successful on attempt $attempt!"
            deployment_succeeded=true
            break 2
        fi

        apply_exit_code=$?

        if [[ $apply_exit_code -eq 124 ]]; then
            echo "Infrastructure deployment timed out after ${APPLY_TIMEOUT_SECONDS}s on attempt $attempt"
        else
            echo "Infrastructure deployment failed on attempt $attempt"
        fi

        if [[ $attempt -lt $MAX_RETRIES ]]; then
            echo "Will retry with the next location and server type combination..."

            echo "Cleaning up partial deployment..."
            terraform destroy -auto-approve || true

            echo "Waiting ${RETRY_DELAY}s for resources to become available..."
            sleep $RETRY_DELAY
        fi

        attempt=$((attempt + 1))
    done
done

if [[ "$deployment_succeeded" != true ]]; then
    echo "All deployment attempts failed after $MAX_RETRIES tries"
    echo ""
    echo "This usually means:"
    echo "   1. High demand for Hetzner Cloud resources in EU regions"
    echo "   2. Your account may have resource limits"
    echo "   3. Try again later when resources become available"
    echo ""
    echo "Manual solutions:"
    echo "   1. Check Hetzner Console for resource limits"
    echo "   2. Try different server types manually"
    echo "   3. Contact Hetzner support for resource availability"
    exit 1
fi

echo ""
echo "Infrastructure ready! Proceeding with application deployment..."

# Common SSH options for all ssh and scp commands
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectionAttempts=10 -o ConnectTimeout=15 -o ServerAliveInterval=15 -o ServerAliveCountMax=4 -o TCPKeepAlive=yes"

# Continue with the rest of the original cd.sh logic
adminhost=$(terraform output -raw adminhost)
ssh_private_key=$(terraform output ssh_private_key)

eval "$(ssh-agent)"
ssh-add - <<< "$ssh_private_key"
rm -f ssh_private_key || true
echo "$ssh_private_key" > ssh_private_key
chmod 400 ssh_private_key

terraform output -json static-inventory > inventory.json
yq eval -o=yaml '.' inventory.json > inventory.yml

echo "Running ansible playbook setup_nodes.yml via adminhost ($adminhost)..."
ansible-playbook -i inventory.yml setup_nodes.yml --private-key "ssh_private_key"

# user demo needs to exist
ssh $SSH_OPTS "demo@$adminhost" wget -q "https://s3-eu-west-1.amazonaws.com/public.wire.com/artifacts/${ARTIFACT}.tgz"

ssh $SSH_OPTS "demo@$adminhost" tar xzf "${ARTIFACT}.tgz"

# Source and target files
SOURCE="inventory.yml"
cp "${CD_DIR}/../ansible/inventory/offline/staging.yml" "inventory-secondary.yml"
TARGET="inventory-secondary.yml"

# Read assethost IP
ASSETHOST_IP=$(yq eval '.assethost.hosts.assethost.ansible_host' "$SOURCE")
yq eval -i ".assethost.hosts.assethost.ansible_host = \"$ASSETHOST_IP\"" "$TARGET"

# Read kube-node IPs using to_entries
KUBENODE1_IP=$(yq eval '.["kube-node"].hosts | to_entries | .[0].value.ansible_host' "$SOURCE")
KUBENODE2_IP=$(yq eval '.["kube-node"].hosts | to_entries | .[1].value.ansible_host' "$SOURCE")
KUBENODE3_IP=$(yq eval '.["kube-node"].hosts | to_entries | .[2].value.ansible_host' "$SOURCE")

yq eval -i ".kube-node.hosts.kubenode1.ansible_host = \"$KUBENODE1_IP\"" "$TARGET"
yq eval -i ".kube-node.hosts.kubenode2.ansible_host = \"$KUBENODE2_IP\"" "$TARGET"
yq eval -i ".kube-node.hosts.kubenode3.ansible_host = \"$KUBENODE3_IP\"" "$TARGET"

# Read datanodes IPs using to_entries
DATANODE1_IP=$(yq eval '.datanode.hosts | to_entries | .[0].value.ansible_host' "$SOURCE")
DATANODE2_IP=$(yq eval '.datanode.hosts | to_entries | .[1].value.ansible_host' "$SOURCE")
DATANODE3_IP=$(yq eval '.datanode.hosts | to_entries | .[2].value.ansible_host' "$SOURCE")

# Read datanodes names using to_entries
DATANODE1_NAME=$(yq eval '.datanode.hosts | keys | .[0]' "$SOURCE")
DATANODE2_NAME=$(yq eval '.datanode.hosts | keys | .[1]' "$SOURCE")
DATANODE3_NAME=$(yq eval '.datanode.hosts | keys | .[2]' "$SOURCE")

# clean old hosts for datanodes
yq eval -i '.datanodes.hosts = {}' "$TARGET"

# re-create the datanodes group with actual names from SOURCE
yq eval -i ".datanodes.hosts[\"${DATANODE1_NAME}\"].ansible_host = \"${DATANODE1_IP}\"" "$TARGET"
yq eval -i ".datanodes.hosts[\"${DATANODE2_NAME}\"].ansible_host = \"${DATANODE2_IP}\"" "$TARGET"
yq eval -i ".datanodes.hosts[\"${DATANODE3_NAME}\"].ansible_host = \"${DATANODE3_IP}\"" "$TARGET"

# Override network_interface from SOURCE to TARGET for all service groups
NETWORK_INTERFACE=$(yq eval '.datanode.vars.datanode_network_interface' "$SOURCE")
yq eval -i ".cassandra.vars.cassandra_network_interface = \"$NETWORK_INTERFACE\"" "$TARGET"
yq eval -i ".elasticsearch.vars.elasticsearch_network_interface = \"$NETWORK_INTERFACE\"" "$TARGET"
yq eval -i ".minio.vars.minio_network_interface = \"$NETWORK_INTERFACE\"" "$TARGET"
yq eval -i ".postgresql.vars.postgresql_network_interface = \"$NETWORK_INTERFACE\"" "$TARGET"
yq eval -i ".rmq-cluster.vars.rabbitmq_network_interface = \"$NETWORK_INTERFACE\"" "$TARGET"

# re-writing sub-groups for rabbitmq_cluster_master, cassandra_seed, postgresql_rw and postgresql_ro
yq eval -i ".rmq-cluster.vars.rabbitmq_cluster_master = \"${DATANODE1_NAME}\"" "$TARGET"

yq eval -i '.cassandra_seed.hosts = {}' "$TARGET"
yq eval -i ".cassandra_seed.hosts.[\"${DATANODE1_NAME}\"] = \"\"" "$TARGET"

yq eval -i '.postgresql_rw.hosts = {}' "$TARGET"
yq eval -i '.postgresql_ro.hosts = {}' "$TARGET"
yq eval -i ".postgresql_rw.hosts.[\"${DATANODE1_NAME}\"] = \"\"" "$TARGET"
yq eval -i ".postgresql_ro.hosts.[\"${DATANODE2_NAME}\"] = \"\"" "$TARGET"
yq eval -i ".postgresql_ro.hosts.[\"${DATANODE3_NAME}\"] = \"\"" "$TARGET"

# re-populate the postgresql.vars.repmgr_node_config group with actual names from SOURCE
i=1
while IFS= read -r actual_name; do
  yq eval -i "
    .postgresql.vars.repmgr_node_config[\"${actual_name}\"] =
      .postgresql.vars.repmgr_node_config.datanode${i}
    | del(.postgresql.vars.repmgr_node_config.datanode${i})
  " "$TARGET"
  i=$((i+1))
done < <(yq eval -r '.datanode.hosts | keys | .[]' "$SOURCE")

# Extract all kube-node vars from SOURCE and merge into TARGET
KUBE_NODE_VARS_FILE=$(mktemp)
yq eval '.["kube-node"].vars' "$SOURCE" > "$KUBE_NODE_VARS_FILE"
yq eval -i '.kube-node.vars |= load("'"$KUBE_NODE_VARS_FILE"'")' "$TARGET"

rm -f "$KUBE_NODE_VARS_FILE"

echo "created secondary inventory file $TARGET successfully"

scp $SSH_OPTS "$TARGET" "demo@$adminhost":./ansible/inventory/offline/inventory.yml

ssh $SSH_OPTS "demo@$adminhost" cat ./ansible/inventory/offline/inventory.yml || true

# NOTE: Agent is forwarded; so that the adminhost can provision the other boxes
ssh $SSH_OPTS -A "demo@$adminhost" ./bin/offline-deploy.sh

echo ""
echo "Wire offline deployment completed successfully!"
