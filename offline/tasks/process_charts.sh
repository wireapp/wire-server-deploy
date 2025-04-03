#!/usr/bin/env bash
set -x -euo pipefail

OUTPUT_DIR=""
# Default exclude list
IMAGE_EXCLUDE_LIST=""

# Parse the arguments
for arg in "$@"
do
  case $arg in
    OUTPUT_DIR=*)
      OUTPUT_DIR="${arg#*=}"
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
  echo "usage: $0 OUTPUT_DIR=\"output-dir\" [IMAGE_EXCLUDE_LIST=\"image1\|image2...\"]" >&2
  exit 1
fi

echo "Processing Helm charts in ${OUTPUT_DIR}"

touch "${OUTPUT_DIR}"/containers-helm/helm_image_tree.txt

# Check if IMAGE_EXCLUDE_LIST is set, otherwise use a default pattern that matches nothing
EXCLUDE_PATTERN=${IMAGE_EXCLUDE_LIST:-".^"}

echo "Excluding images matching the pattern: $EXCLUDE_PATTERN"

# Get and dump required containers from Helm charts. Omit integration test
# containers (e.g. `quay.io_wire_galley-integration_4.22.0`.)
for chartPath in "${OUTPUT_DIR}"/charts/*; do
  echo "$chartPath"
done | list-helm-containers VALUES_DIR="${OUTPUT_DIR}"/values HELM_IMAGE_TREE_FILE="${OUTPUT_DIR}"/containers-helm/chart-images.txt | grep -v "\-integration:" > "${OUTPUT_DIR}"/images

cat "${OUTPUT_DIR}"/images

grep -vE "$EXCLUDE_PATTERN"  "${OUTPUT_DIR}"/images | create-container-dump  "${OUTPUT_DIR}"/containers-helm

ORIGINAL_DIR="$PWD"
cd "${OUTPUT_DIR}" || { echo "Error: Cannot change to directory ${OUTPUT_DIR}/debs-jammy"; exit 1; }
tar cf containers-helm.tar containers-helm

cd "$ORIGINAL_DIR" || { echo "Error: Cannot change back to original directory"; exit 1; }
