#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR=""
# Default exclude list
IMAGE_EXCLUDE_LIST=""

# Default values type will expect to use prod values
VALUES_TYPE="prod"

# Parse the arguments
for arg in "$@"
do
  case $arg in
    OUTPUT_DIR=*)
      OUTPUT_DIR="${arg#*=}"
      ;;
    VALUES_TYPE=*)
      VALUES_TYPE="${arg#*=}"
      ;;
    IMAGE_EXCLUDE_LIST=*)
      IMAGE_EXCLUDE_LIST="${arg#*=}"
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

# Check if OUTPUT_DIR is set
if [[ -z "$OUTPUT_DIR" ]]; then
  echo "usage: $0 OUTPUT_DIR=\"output-dir\" [IMAGE_EXCLUDE_LIST=\"image1\|image2...\"] [VALUES_TYPE=\"prod\"]" >&2
  exit 1
fi

echo "Processing Helm charts in ${OUTPUT_DIR} with VALUES_TYPE=${VALUES_TYPE}"

HELM_IMAGE_TREE_FILE="${OUTPUT_DIR}/versions/helm_image_tree.json"

# Check if IMAGE_EXCLUDE_LIST is set, otherwise use a default pattern that matches nothing
EXCLUDE_PATTERN=${IMAGE_EXCLUDE_LIST:-".^"}

echo "Excluding images matching the pattern: $EXCLUDE_PATTERN"

# Get and dump required containers from Helm charts. Omit integration test
# containers (e.g. `quay.io_wire_galley-integration_4.22.0`.)
for chartPath in "${OUTPUT_DIR}"/charts/*; do
  echo "$chartPath"
done | list-helm-containers VALUES_DIR="${OUTPUT_DIR}"/values HELM_IMAGE_TREE_FILE="$HELM_IMAGE_TREE_FILE" VALUES_TYPE="$VALUES_TYPE" | grep -v "\-integration:" > "${OUTPUT_DIR}"/images

# Omit integration test
# containers (e.g. `quay.io_wire_galley-integration_4.22.0`.)
sed -i '/-integration/d' "${HELM_IMAGE_TREE_FILE}"

# Replace docker.io/bitnami with docker.io/bitnamilegacy and log updated images
# https://github.com/bitnami/charts/issues/35164
echo "Replacing bitnami with bitnamilegacy..."
sed -i 's|bitnami/|bitnamilegacy/|g' "${OUTPUT_DIR}"/images
sed -i 's|bitnami/|bitnamilegacy/|g' "${HELM_IMAGE_TREE_FILE}"
echo "Updated images:"
grep "bitnamilegacy" "${OUTPUT_DIR}"/images || echo "No bitnami images found"

grep -vE "$EXCLUDE_PATTERN"  "${OUTPUT_DIR}"/images | create-container-dump  "${OUTPUT_DIR}"/containers-helm

tar cf "${OUTPUT_DIR}"/containers-helm.tar -C "${OUTPUT_DIR}" containers-helm
mv "${OUTPUT_DIR}/containers-helm/images.json" "${OUTPUT_DIR}"/versions/containers_helm_images.json
