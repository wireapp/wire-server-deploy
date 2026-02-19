#!/usr/bin/env bash

set -euo pipefail

CD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${CD_DIR}/../terraform/examples/wiab-staging-hetzner"
VALUES_DIR="${CD_DIR}/../values"
COMMIT_HASH="${GITHUB_SHA}"
ARTIFACT="wire-server-deploy-static-${COMMIT_HASH}"

# Retry configuration
MAX_RETRIES=3
RETRY_DELAY=30

echo "Wire Offline Deployment with Retry Logic"
echo "========================================"

function cleanup {
  (cd "$TF_DIR" && terraform destroy -auto-approve)
  echo "Cleanup completed"
}
trap cleanup EXIT

cd "$TF_DIR"
terraform init

# Retry loop for terraform apply
echo "Starting deployment with automatic retry on resource unavailability..."
for attempt in $(seq 1 $MAX_RETRIES); do
    echo ""
    echo "Deployment attempt $attempt of $MAX_RETRIES"
    date

    if terraform apply -auto-approve; then
        echo "Infrastructure deployment successful on attempt $attempt!"
        break
    else
        echo "Infrastructure deployment failed on attempt $attempt"

        if [[ $attempt -lt $MAX_RETRIES ]]; then
            echo "Will retry with different configuration..."

            # Clean up partial deployment
            echo "Cleaning up partial deployment..."
            terraform destroy -auto-approve || true

            # Wait for resources to potentially become available
            echo "Waiting ${RETRY_DELAY}s for resources to become available..."
            sleep $RETRY_DELAY

            # Modify configuration for better availability
            echo "Adjusting server type preferences for attempt $((attempt + 1))..."
            case $attempt in
                1)
                    # Attempt 2: Prioritize cpx22 and cx53
                    sed -i.bak 's/"cx33", "cpx22", "cx43"/"cpx22", "cx43", "cx33"/' main.tf
                    sed -i.bak 's/"cx43", "cx53", "cpx42"/"cx53", "cpx42", "cx43"/' main.tf
                    echo "   -> Prioritizing cpx22 and cx53 server types"
                    ;;
                2)
                    # Attempt 3: Use biggest available types
                    sed -i.bak 's/"cpx22", "cx43", "cx33"/"cx43", "cx33", "cpx22"/' main.tf
                    sed -i.bak 's/"cx53", "cpx42", "cx43"/"cpx42", "cx43", "cx53"/' main.tf
                    echo "   -> Using Biggest available server types"
                    ;;
            esac

            terraform init -reconfigure
        else
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

            # Restore original config
            if [[ -f main.tf.bak ]]; then
                mv main.tf.bak main.tf
                terraform init -reconfigure
            fi

            exit 1
        fi
    fi
done

# Restore original config after successful deployment
if [[ -f main.tf.bak ]]; then
    mv main.tf.bak main.tf
    terraform init -reconfigure
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
ssh "$SSH_OPTS" "demo@$adminhost" wget -q "https://s3-eu-west-1.amazonaws.com/public.wire.com/artifacts/${ARTIFACT}.tgz"

# shellcheck disable=SC2029
ssh "$SSH_OPTS" "demo@$adminhost" tar xzf "${ARTIFACT}.tgz"

# override for ingress-nginx-controller values for hetzner environment $TF_DIR/setup_nodes.yml
scp "$SSH_OPTS" "$VALUES_DIR/ingress-nginx-controller/hetzner-ci.example.yaml" "demo@$adminhost:./values/ingress-nginx-controller/prod-values.example.yaml"

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

scp "$SSH_OPTS" "$TARGET" "demo@$adminhost":./ansible/inventory/offline/inventory.yml

ssh "$SSH_OPTS" "demo@$adminhost" cat ./ansible/inventory/offline/inventory.yml || true

# NOTE: Agent is forwarded; so that the adminhost can provision the other boxes
ssh "$SSH_OPTS" -A "demo@$adminhost" ./bin/offline-deploy.sh

echo ""
echo "Wire offline deployment completed successfully!"
cleanup
