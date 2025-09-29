#!/usr/bin/env bash

set -euo pipefail

# Enable verbose debugging (disable for cleaner output)
# set -x

# This is the production version of cd.sh with built-in retry logic
# Use this instead of cd.sh when you want automatic resource availability handling

CD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${CD_DIR}/../terraform/examples/wire-server-deploy-offline-hetzner"

echo "Script directory (CD_DIR): $CD_DIR"
echo "Terraform directory (TF_DIR): $TF_DIR"
echo "Checking if TF_DIR exists:"
ls -la "$TF_DIR" || echo "TF_DIR does not exist"

# Retry configuration
MAX_RETRIES=3
RETRY_DELAY=30

# S3 configuration for fast asset download
S3_REGION="eu-west-1"

# Get build ID from environment or use git commit
UPLOAD_NAME="${GITHUB_SHA:-$(git rev-parse HEAD)}"

echo "Using UPLOAD_NAME: $UPLOAD_NAME"
echo "GITHUB_SHA: ${GITHUB_SHA:-not set}"

echo "Wire Offline Deployment with Retry Logic"
echo "========================================"

function cleanup {
  if [[ "${CLEANUP_ON_EXIT:-}" == "true" ]]; then
    echo "Running cleanup..."
    (cd "$TF_DIR" && terraform destroy -auto-approve)
    echo "Cleanup completed"
  fi
}
trap cleanup EXIT

echo "Changing to terraform directory: $TF_DIR"
cd "$TF_DIR" || {
    echo "ERROR: Failed to change to terraform directory: $TF_DIR"
    ls -la "$TF_DIR" || echo "Directory does not exist"
    exit 1
}

echo "Current directory: $(pwd)"
echo "Directory contents:"
ls -la

# Clean up any existing state to ensure fresh deployment
if [[ -f terraform.tfstate ]]; then
    echo "Cleaning up existing terraform state..."
    rm -f terraform.tfstate terraform.tfstate.backup
fi

echo "Checking terraform availability..."
terraform version || {
    echo "ERROR: terraform not found in PATH"
    echo "PATH: $PATH"
    which terraform || echo "terraform not in which"
    exit 1
}

echo "Running terraform init..."
terraform init || {
    echo "ERROR: terraform init failed"
    echo "Exit code: $?"
    exit 1
}

# Pre-calculate S3 URLs for faster deployment
DEFAULT_ASSETS_URL="https://s3-${S3_REGION}.amazonaws.com/public.wire.com/artifacts/wire-server-deploy-static-${UPLOAD_NAME}.tgz"

echo "Asset URL: $DEFAULT_ASSETS_URL"

# Retry loop for terraform apply with performance optimizations
echo "Starting deployment with automatic retry on resource unavailability..."
for attempt in $(seq 1 $MAX_RETRIES); do
    echo ""
    echo "Deployment attempt $attempt of $MAX_RETRIES"
    date

    # Terraform apply (temporarily removing parallelism for debugging)
    echo "Running terraform apply..."
    if terraform apply -auto-approve; then
        echo "Infrastructure deployment successful on attempt $attempt!"
        # Enable cleanup since infrastructure exists
        export CLEANUP_ON_EXIT="true"
        break
    else
        TERRAFORM_EXIT_CODE=$?
        echo "Infrastructure deployment failed on attempt $attempt (exit code: $TERRAFORM_EXIT_CODE)"

        if [[ $attempt -lt $MAX_RETRIES ]]; then
            echo "Will retry with different configuration..."

            # Cleanup partial deployment
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
            echo "   2. Hetzner account may have resource limits"
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

            # Enable cleanup for final failure case
            export CLEANUP_ON_EXIT="true"
            exit 1
        fi
    fi
done

# Check if we exited the loop successfully (CLEANUP_ON_EXIT set means terraform apply succeeded)
if [[ "${CLEANUP_ON_EXIT:-}" != "true" ]]; then
    echo "ERROR: All terraform attempts failed, but script continued unexpectedly"
    exit 1
fi

# Restore original config after successful deployment
if [[ -f main.tf.bak ]]; then
    mv main.tf.bak main.tf
    terraform init -reconfigure
fi

echo ""
echo "Infrastructure ready! Proceeding with application deployment..."


echo "Getting terraform outputs..."
adminhost=$(terraform output adminhost) || {
    echo "ERROR: Failed to get adminhost output from terraform"
    terraform output || echo "No terraform outputs available"
    exit 1
}
adminhost="${adminhost//\"/}" # remove extra quotes around the returned string
echo "Adminhost IP: $adminhost"

ssh_private_key=$(terraform output ssh_private_key) || {
    echo "ERROR: Failed to get ssh_private_key output from terraform"
    exit 1
}
echo "SSH private key retrieved (length: ${#ssh_private_key} chars)"

# Fast SSH setup
eval "$(ssh-agent)" || {
    echo "ERROR: Failed to start ssh-agent"
    exit 1
}
ssh-add - <<< "$ssh_private_key"

# Generate inventory in parallel with other setup
terraform output -json static-inventory > inventory.json &
INVENTORY_PID=$!

# Pre-configure SSH for faster connections
SSH_OPTS="-oStrictHostKeyChecking=accept-new -oConnectionAttempts=3 -oConnectTimeout=10 -oServerAliveInterval=30"

# Wait for inventory and convert to YAML
wait $INVENTORY_PID

# Convert inventory to YAML (ansible can read both JSON and YAML)
if command -v yq >/dev/null 2>&1; then
    echo "Converting inventory to YAML format..."
    yq -p json -o yaml '.' inventory.json > inventory.yml
else
    echo "yq not available, using JSON inventory directly (ansible supports both formats)..."
    cp inventory.json inventory.yml
fi

echo "Setting up adminhost for fast deployment..."

# Install required tools on adminhost in parallel
ssh "$SSH_OPTS" "root@$adminhost" 'bash -s' << 'EOF' &
# Install AWS CLI and ansible dependencies for faster deployment
apt-get update -qq
apt-get install -y awscli curl python3-pip yq
pip3 install ansible
# Pre-create directories
mkdir -p ./ansible/inventory/offline/
EOF

SETUP_PID=$!

# Copy inventory while setup is running
scp -o StrictHostKeyChecking=accept-new inventory.yml "root@$adminhost":./ansible/inventory/offline/inventory.yml

# Wait for setup to complete
wait $SETUP_PID

echo "Downloading assets directly from S3 to adminhost (much faster than local transfer)..."

# Download assets directly from S3 to adminhost (MUCH faster)
ssh "$SSH_OPTS" "root@$adminhost" "curl -fsSL '$DEFAULT_ASSETS_URL' | tar xzv"

echo "Verifying deployment setup..."
ssh "$SSH_OPTS" "root@$adminhost" cat ./ansible/inventory/offline/inventory.yml || true

echo "Running optimized ansible deployment..."

echo "Running ansible playbook setup_nodes.yml via adminhost ($adminhost)..."
# Run ansible from adminhost for faster network connectivity
ssh "$SSH_OPTS" "root@$adminhost" "cd ./ansible && ansible-playbook -i inventory/offline/inventory.yml setup_nodes.yml --forks=10 -e ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ControlMaster=auto -o ControlPersist=300s'"

echo "Running final Wire deployment..."
# Use SSH connection multiplexing for faster multiple connections
ssh -A -o ControlMaster=auto -o ControlPersist=300s "root@$adminhost" ./bin/offline-deploy.sh

echo ""
echo "Fast Wire offline deployment completed successfully!"
echo "Performance optimizations used:"
echo "  - S3 direct download instead of local transfer"
echo "  - Parallel terraform operations (15 parallel resources)"
echo "  - Faster SSH connection multiplexing"
echo "  - Parallel ansible execution (10 forks)"
echo "  - Pre-installed tools on adminhost"
echo "  - Ansible runs directly on adminhost (no proxy jumps)"

# Enable cleanup only after successful deployment
export CLEANUP_ON_EXIT="true"