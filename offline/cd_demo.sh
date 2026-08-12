#!/usr/bin/env bash

set -euo pipefail

CD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${CD_DIR}/../terraform/examples/wiab-demo-hetzner"
# shellcheck disable=SC2034  # May be used in future versions
BIN_DIR="${CD_DIR}/../bin"
# shellcheck disable=SC2034  # May be used in future versions
ARTIFACTS_DIR="${CD_DIR}/demo-build/output"
ANSIBLE_DIR="${CD_DIR}/../ansible"
INVENTORY_DIR="${ANSIBLE_DIR}/inventory/demo"
INVENTORY_FILE="${INVENTORY_DIR}/host.yml"
TF_VARS_FILE="${TF_DIR}/retry-selection.auto.tfvars.json"
TEST_USER="demo"
COMMIT_HASH="${GITHUB_SHA}"

# Retry matrix
LOCATIONS=("hel1" "fsn1" "nbg1")
SERVER_TYPES=("cx53" "cpx62")

# Retry configuration
RETRY_DELAY=30
APPLY_TIMEOUT_SECONDS=300


function cleanup {
  (cd "$TF_DIR" && terraform destroy -auto-approve)
  echo "done"
}

trap cleanup EXIT

function persist_terraform_vars {
	local location="$1"
	local server_type="$2"

	printf '{\n  "location": "%s",\n  "server_type": "%s"\n}\n' \
		"$location" \
		"$server_type" > "$TF_VARS_FILE"
}

cd "$TF_DIR"
terraform init

if ! command -v timeout >/dev/null 2>&1; then
	echo "The 'timeout' command is required but not installed"
	exit 1
fi

if [[ ${#LOCATIONS[@]} -eq 0 || ${#SERVER_TYPES[@]} -eq 0 ]]; then
	echo "No location or server type preferences configured in the retry matrix"
	exit 1
fi

location_count=${#LOCATIONS[@]}
server_type_count=${#SERVER_TYPES[@]}
MAX_RETRIES=$((location_count * server_type_count))

echo "Retry plan: ${location_count} locations x ${server_type_count} server types = ${MAX_RETRIES} attempts"

attempt=1
deployment_succeeded=false

for server_type_index in $(seq 0 $((server_type_count - 1))); do
	for location_index in $(seq 0 $((location_count - 1))); do
		attempt_location="${LOCATIONS[$location_index]}"
		attempt_server_type="${SERVER_TYPES[$server_type_index]}"

		persist_terraform_vars "$attempt_location" "$attempt_server_type"

		echo "Deployment attempt $attempt of $MAX_RETRIES"
		echo "   -> location=${attempt_location}, size=${attempt_server_type}"
		date

		if timeout "${APPLY_TIMEOUT_SECONDS}s" terraform apply -auto-approve; then
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
	exit 1
fi

echo ""
echo "Infrastructure ready! Proceeding with application deployment..."

host=$(terraform output -raw host)
ssh_private_key=$(terraform output ssh_private_key)

rm -f "${INVENTORY_DIR}/ssh_private_key" || true
echo "$ssh_private_key" > "${INVENTORY_DIR}/ssh_private_key"
chmod 400 "${INVENTORY_DIR}/ssh_private_key"

# clean old host verification keys to avoid SSH issues
ssh-keygen -R "$host" || true

# create demo user on the remote host
ssh -v -oStrictHostKeyChecking=accept-new -oConnectionAttempts=10 -i "${INVENTORY_DIR}/ssh_private_key" "root@$host" \
"useradd -m -s /bin/bash ${TEST_USER} && \
usermod -aG sudo ${TEST_USER} && \
mkdir -p /home/${TEST_USER}/.ssh && \
cp /root/.ssh/authorized_keys /home/${TEST_USER}/.ssh/ && \
chown -R ${TEST_USER}:${TEST_USER} /home/${TEST_USER}/.ssh && \
chmod 700 /home/${TEST_USER}/.ssh && \
chmod 600 /home/${TEST_USER}/.ssh/authorized_keys && \
echo '${TEST_USER} ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers.d/${TEST_USER}"

# update inventory file with host details
yq eval -i ".wiab.hosts.deploy_node.ansible_host = \"$host\"" "${INVENTORY_FILE}"
yq eval -i ".wiab.hosts.deploy_node.ansible_ssh_private_key_file = \"${INVENTORY_DIR}/ssh_private_key\"" "${INVENTORY_FILE}"
yq eval -i ".wiab.vars.artifact_hash = \"$COMMIT_HASH\"" "${INVENTORY_FILE}"
yq eval -i ".wiab.hosts.deploy_node.ansible_user = \"$TEST_USER\"" "${INVENTORY_FILE}"

echo "Running ansible playbook deploy_wiab.yml against node $host"
# deploying demo-wiab
ansible-playbook -i "${INVENTORY_FILE}" "${ANSIBLE_DIR}/wiab-demo/deploy_wiab.yml" --skip-tags verify_dns
# cleaning demo-wiab
ansible-playbook -i "${INVENTORY_FILE}" "${ANSIBLE_DIR}/wiab-demo/clean_cluster.yml" --tags remove_minikube,remove_artifacts,remove_packages,remove_iptables,remove_ssh
