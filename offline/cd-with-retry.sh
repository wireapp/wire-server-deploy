#!/usr/bin/env bash

set -euo pipefail

# This is the production version of cd.sh with built-in retry logic
# Use this instead of cd.sh when you want automatic resource availability handling

CD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${CD_DIR}/../terraform/examples/wire-server-deploy-offline-hetzner"
ARTIFACTS_DIR="${CD_DIR}/default-build/output"

# S3 configuration for asset download fallback
S3_REGION="eu-west-1"
UPLOAD_NAME="${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo 'unknown')}"

# Ensure assets are available (download from S3 if local assets don't exist)
if [[ ! -f "$ARTIFACTS_DIR/assets.tgz" && -n "${GITHUB_SHA:-}" ]]; then
    echo "Local assets not found. Downloading from S3..."
    echo "Using UPLOAD_NAME: $UPLOAD_NAME"

    mkdir -p "$ARTIFACTS_DIR"
    S3_URL="https://s3-${S3_REGION}.amazonaws.com/public.wire.com/artifacts/wire-server-deploy-static-${UPLOAD_NAME}.tgz"

    if curl -fsSL "$S3_URL" -o "$ARTIFACTS_DIR/assets.tgz"; then
        echo "Successfully downloaded assets from S3"
    else
        echo "ERROR: Failed to download assets from S3: $S3_URL"
        echo "Please ensure the build artifacts exist or run the full build first"
        exit 1
    fi
elif [[ -f "$ARTIFACTS_DIR/assets.tgz" ]]; then
    echo "Using existing local assets: $ARTIFACTS_DIR/assets.tgz"
else
    echo "ERROR: No assets available and no GITHUB_SHA set for S3 download"
    echo "Please run the build first or set GITHUB_SHA environment variable"
    exit 1
fi

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
                    # Attempt 2: Prioritize cx22 and cx41
                    sed -i.bak 's/"cpx21", "cx22", "cx21", "cpx11"/"cx22", "cpx11", "cpx21", "cx21"/' main.tf
                    sed -i.bak 's/"cpx31", "cpx41", "cx31", "cx41"/"cx41", "cpx31", "cx31", "cx41"/' main.tf
                    echo "   -> Prioritizing cx22 and cx41 server types"
                    ;;
                2)
                    # Attempt 3: Use smallest available types
                    sed -i.bak 's/"cx22", "cpx11", "cpx21", "cx21"/"cpx11", "cx21", "cx22", "cpx21"/' main.tf
                    sed -i.bak 's/"cx41", "cpx31", "cx31", "cx41"/"cpx31", "cpx31", "cpx11", "cx21"/' main.tf
                    echo "   -> Using smallest available server types"
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

# Continue with the rest of the original cd.sh logic
adminhost=$(terraform output adminhost)
adminhost="${adminhost//\"/}" # remove extra quotes around the returned string
ssh_private_key=$(terraform output ssh_private_key)

eval "$(ssh-agent)"
ssh-add - <<< "$ssh_private_key"

terraform output -json static-inventory > inventory.json
yq eval -P '.' inventory.json > inventory.yml

ssh -oStrictHostKeyChecking=accept-new -oConnectionAttempts=10 "root@$adminhost" tar xzv < "$ARTIFACTS_DIR/assets.tgz"

scp inventory.yml "root@$adminhost":./ansible/inventory/offline/inventory.yml

ssh "root@$adminhost" cat ./ansible/inventory/offline/inventory.yml || true

echo "Running ansible playbook setup_nodes.yml via adminhost ($adminhost)..."
ansible-playbook -i inventory.yml setup_nodes.yml --private-key "ssh_private_key" \
  -e "ansible_ssh_common_args='-o ProxyCommand=\"ssh -W %h:%p -q root@$adminhost -i ssh_private_key\" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'"

# NOTE: Agent is forwarded; so that the adminhost can provision the other boxes
ssh -A "root@$adminhost" ./bin/offline-deploy.sh

echo ""
echo "Wire offline deployment completed successfully!"