#!/usr/bin/env bash

set -euo pipefail

# Script to sync Kubernetes secret values to Wire server secrets YAML file
# Usage: sync-k8s-secret-to-wire-secrets.sh <secret-name> <secret-key> <yaml-file> <yaml-path1> [yaml-path2] ...
#
# Example:
#   sync-k8s-secret-to-wire-secrets.sh wire-postgresql-external-secret password values/wire-server/secrets.yaml \
#     .brig.secrets.pgPassword .galley.secrets.pgPassword

usage() {
    cat << EOF
Usage: $(basename "$0") <secret-name> <secret-key> <yaml-file> <yaml-path>...

Syncs a value from a Kubernetes secret to one or more paths in a YAML file.

Arguments:
  secret-name   Name of the Kubernetes secret
  secret-key    Key within the secret to retrieve
  yaml-file     Path to the YAML file to update
  yaml-path     YAML path(s) to update (e.g., .brig.secrets.pgPassword)

Options:
  -n, --namespace   Kubernetes namespace (default: default)
  -h, --help        Show this help message

Examples:
  # PostgreSQL password sync (most common)
  $(basename "$0") wire-postgresql-external-secret password \\
    values/wire-server/secrets.yaml \\
    .brig.secrets.pgPassword .galley.secrets.pgPassword .spar.secrets.pgPassword .gundeck.secrets.pgPassword

  # RabbitMQ password sync
  $(basename "$0") rabbitmq-secret password \\
    values/wire-server/secrets.yaml \\
    .brig.secrets.rabbitmq.password .galley.secrets.rabbitmq.password

  # Redis password sync
  $(basename "$0") redis-secret password \\
    values/wire-server/secrets.yaml \\
    .brig.secrets.redis.password
EOF
    exit 1
}

# Parse arguments
NAMESPACE="default"
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            break
            ;;
    esac
done

# Validate required arguments
if [ $# -lt 4 ]; then
    echo "❌ ERROR: Missing required arguments"
    echo ""
    usage
fi

SECRET_NAME="$1"
SECRET_KEY="$2"
YAML_FILE="$3"
shift 3
YAML_PATHS=("$@")

echo "=================================================="
echo "Wire Secrets Synchronization"
echo "=================================================="
echo ""
echo "Secret: $SECRET_NAME/$SECRET_KEY (namespace: $NAMESPACE)"
echo "Target: $YAML_FILE"
echo "Paths: ${YAML_PATHS[*]}"
echo ""

# Check if kubectl is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ ERROR: Cannot access Kubernetes cluster"
    echo "   Ensure kubectl is configured and cluster is accessible"
    exit 1
fi
echo "✓ Kubernetes cluster is accessible"

# Check if the K8s secret exists
if ! kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &> /dev/null; then
    echo "❌ ERROR: Kubernetes secret '$SECRET_NAME' not found in namespace '$NAMESPACE'"
    exit 1
fi
echo "✓ Found Kubernetes secret: $SECRET_NAME"

# Retrieve the value from K8s secret
SECRET_VALUE=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath="{.data.$SECRET_KEY}" | base64 --decode)
if [ -z "$SECRET_VALUE" ]; then
    echo "❌ ERROR: Retrieved value is empty (key '$SECRET_KEY' not found or empty)"
    exit 1
fi
echo "✓ Retrieved value from secret (${#SECRET_VALUE} chars)"

# Check if YAML file exists
if [ ! -f "$YAML_FILE" ]; then
    echo "❌ ERROR: YAML file not found: $YAML_FILE"
    exit 1
fi
echo "✓ Found YAML file: $YAML_FILE"

# Backup the original file
cp "$YAML_FILE" "$YAML_FILE.bak"
echo "✓ Created backup: $YAML_FILE.bak"

# Update all specified YAML paths
if command -v yq &> /dev/null; then
    echo "✓ Using yq for YAML manipulation"
    for yaml_path in "${YAML_PATHS[@]}"; do
        echo "  Updating: $yaml_path"
        yq -y "$yaml_path = \"$SECRET_VALUE\"" "$YAML_FILE" > "$YAML_FILE.tmp" && mv "$YAML_FILE.tmp" "$YAML_FILE"
    done
else
    echo "❌ ERROR: yq is required for this script"
    echo "   Install yq: https://github.com/kislyuk/yq"
    rm "$YAML_FILE.bak"
    exit 1
fi

# Verify the update
echo ""
echo "Verification:"
SUCCESS=true
for yaml_path in "${YAML_PATHS[@]}"; do
    # Use yq to extract the actual value at the specific path
    if command -v yq &> /dev/null; then
        EXTRACTED_VALUE=$(yq -r "$yaml_path" "$YAML_FILE" 2>/dev/null || echo "")
        if [ "$EXTRACTED_VALUE" = "$SECRET_VALUE" ]; then
            echo "  ✓ $yaml_path: synced"
        else
            echo "  ⚠ $yaml_path: verification failed (expected ${#SECRET_VALUE} chars, got ${#EXTRACTED_VALUE} chars)"
            SUCCESS=false
        fi
    else
        # Fallback verification (less reliable)
        FIELD_NAME=$(echo "$yaml_path" | awk -F. '{print $NF}')
        EXTRACTED_VALUE=$(grep "$FIELD_NAME:" "$YAML_FILE" | head -1 | awk '{print $2}' | tr -d '"' | tr -d "'" || echo "")
        if [ "$EXTRACTED_VALUE" = "$SECRET_VALUE" ]; then
            echo "  ✓ $yaml_path: synced"
        else
            echo "  ⚠ $yaml_path: verification inconclusive (fallback method)"
            SUCCESS=false
        fi
    fi
done

echo ""
if [ "$SUCCESS" = true ]; then
    echo "✅ SUCCESS: All paths synchronized"
else
    echo "⚠️  WARNING: Verification inconclusive for some paths"
    echo "   Manual verification recommended: cat $YAML_FILE"
fi
echo "   Backup saved: $YAML_FILE.bak"

echo ""
echo "=================================================="
echo "Synchronization completed!"
echo "=================================================="
