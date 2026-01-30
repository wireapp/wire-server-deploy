#!/usr/bin/env bash

set -euo pipefail

CD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${CD_DIR}/../terraform/examples/wire-server-deploy-offline-hetzner"
ARTIFACTS_DIR="${CD_DIR}/default-build/output"
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
                    # Attempt 2: Prioritize cx22 and cx41
                    sed -i.bak 's/"cx23", "cx33", "cpx22"/"cx33", "cpx22", "cx23"/' main.tf
                    sed -i.bak 's/"cx33", "cx43", "cpx32"/"cx43", "cpx32", "cx33"/' main.tf
                    echo "   -> Prioritizing cx33 and cx43 server types"
                    ;;
                2)
                    # Attempt 3: Use smallest available types
                    sed -i.bak 's/"cx33", "cpx22", "cx23"/"cpx22", "cx23", "cx33"/' main.tf
                    sed -i.bak 's/"cx43", "cpx32", "cx33"/"cpx32", "cx33", "cx43"/' main.tf
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

# override for ingress-nginx-controller values for hetzner environment $TF_DIR/setup_nodes.yml
scp $SSH_OPTS "$VALUES_DIR/ingress-nginx-controller/hetzner-ci.example.yaml" "root@$adminhost:./values/ingress-nginx-controller/prod-values.example.yaml"

scp $SSH_OPTS inventory.yml "root@$adminhost":./ansible/inventory/offline/inventory.yml

ssh $SSH_OPTS "root@$adminhost" cat ./ansible/inventory/offline/inventory.yml || true

echo "Running ansible playbook setup_nodes.yml via adminhost ($adminhost)..."
ansible-playbook -i inventory.yml setup_nodes.yml --private-key "ssh_private_key"

# NOTE: Agent is forwarded; so that the adminhost can provision the other boxes
ssh $SSH_OPTS -A "root@$adminhost" ./bin/offline-deploy.sh

echo ""
echo "Wire offline deployment completed successfully!"
cleanup
