#!/usr/bin/env bash

set -euo pipefail

CD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${CD_DIR}/../terraform/examples/wire-server-deploy-offline-hetzner"
VALUES_DIR="${CD_DIR}/../values"

COMMIT_HASH="${GITHUB_SHA}"
ARTIFACT="wire-server-deploy-static-${COMMIT_HASH}"

# Retry matrix
LOCATIONS=("hel1" "fsn1" "nbg1")
SMALL_SERVER_TYPES=("cx23" "cx33" "cpx22")
MEDIUM_SERVER_TYPES=("cx33" "cx43" "cpx32")

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

# Retry loop for terraform apply
echo "Starting deployment with automatic retry on resource unavailability..."
echo "Retry plan: ${location_count} locations x ${server_type_count} server type pairs = ${MAX_RETRIES} attempts"

attempt=1
deployment_succeeded=false

for server_type_index in $(seq 0 $((server_type_count - 1))); do
    for location_index in $(seq 0 $((location_count - 1))); do
        attempt_location="${LOCATIONS[$location_index]}"
        attempt_small_server_type="${SMALL_SERVER_TYPES[$server_type_index]}"
        attempt_medium_server_type="${MEDIUM_SERVER_TYPES[$server_type_index]}"

        terraform_args=(
            "-var=location=${attempt_location}"
            "-var=small_server_type=${attempt_small_server_type}"
            "-var=medium_server_type=${attempt_medium_server_type}"
        )

        echo ""
        echo "Deployment attempt $attempt of $MAX_RETRIES"
        echo "   -> location=${attempt_location}, small=${attempt_small_server_type}, medium=${attempt_medium_server_type}"
        date

        if timeout "${APPLY_TIMEOUT_SECONDS}s" terraform apply -auto-approve "${terraform_args[@]}"; then
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
            terraform destroy -auto-approve "${terraform_args[@]}" || true

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
adminhost=$(terraform output adminhost)
adminhost="${adminhost//\"/}" # remove extra quotes around the returned string
ssh_private_key=$(terraform output ssh_private_key)

eval "$(ssh-agent)"
ssh-add - <<< "$ssh_private_key"
rm -f ssh_private_key || true
echo "$ssh_private_key" > ssh_private_key
chmod 400 ssh_private_key

# TO-DO: make changes to test the deployment with demo user in 
terraform output -json static-inventory > inventory.json
yq eval -o=yaml '.' inventory.json > inventory.yml

ssh $SSH_OPTS "root@$adminhost" wget -q "https://s3-eu-west-1.amazonaws.com/public.wire.com/artifacts/${ARTIFACT}.tgz"

ssh $SSH_OPTS "root@$adminhost" tar xzf "$ARTIFACT.tgz"

scp $SSH_OPTS inventory.yml "root@$adminhost":./ansible/inventory/offline/inventory.yml

ssh $SSH_OPTS "root@$adminhost" cat ./ansible/inventory/offline/inventory.yml || true

echo "Running ansible playbook setup_nodes.yml via adminhost ($adminhost)..."
ansible-playbook -i inventory.yml setup_nodes.yml --private-key "ssh_private_key"

# NOTE: Agent is forwarded; so that the adminhost can provision the other boxes
ssh $SSH_OPTS -A "root@$adminhost" ./bin/offline-deploy.sh

echo ""
echo "Wire offline deployment completed successfully!"
cleanup
