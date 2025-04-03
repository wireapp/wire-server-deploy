#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# this directory will be created to store all the output files
OUTPUT_DIR="$SCRIPT_DIR/output"
# ROOT_DIR points to dir where ansible,bin, values etc can be located
# expected structure to be: /wire-server-deploy/offline/default-build/build.sh
# /wire-server-deploy/ansible
ROOT_DIR="${SCRIPT_DIR}/../../"

mkdir -p "${OUTPUT_DIR}"/containers-{helm,other,system,adminhost} "${OUTPUT_DIR}"/binaries

# Define the output tar file
OUTPUT_TAR="${OUTPUT_DIR}/assets.tgz"

TASKS_DIR="${SCRIPT_DIR}/../tasks"

# for optmization purposes, if these tarballs are already processed by previous profiles check wire-server-deploy/.github/workflows/offline.yml, one can copy those artifacts from previous profiles to your profile by using
#cp $SCRIPT_DIR/../<profile-dir>/output/containers-helm.tar "${OUTPUT_DIR}"/
# one need to comment the tasks below for which one wants to optimize the build

# Any of the tasks can be skipped by commenting them out 
# however, mind the dependencies between them and how they are grouped

# Processing helm charts
# --------------------------

# copying charts from the default build
cp -r "${SCRIPT_DIR}"/../default-build/output/charts "${OUTPUT_DIR}"/

# copy values from the default build
cp -r "${SCRIPT_DIR}"/../default-build/output/values "${OUTPUT_DIR}"/s

# copying containers-helm directory from the default build
cp -r "${SCRIPT_DIR}"/../default-build/output/containers-helm "${OUTPUT_DIR}"/

# here removing the federation image from cintainers-helm directory
post_chart_process_1.sh "${OUTPUT_DIR}"/
# --------------------------

# Following tasks are independent from each other
# --------------------------

# copying containers-adminhost directory from the default build
cp -r "${SCRIPT_DIR}"/../default-build/output/containers-adminhost "${OUTPUT_DIR}"/

# copy debs-jammy.tar from the default build
cp -r "${SCRIPT_DIR}"/../default-build/output/debs-jammy.tar "${OUTPUT_DIR}"/

# copy containers-system.tar from the default build
cp -r "${SCRIPT_DIR}"/../default-build/output/containers-system.tar "${OUTPUT_DIR}"/

# copy binaries.tar from the default build
cp -r "${SCRIPT_DIR}"/../default-build/output/binaries.tar "${OUTPUT_DIR}"/

# --------------------------

# custom scripts to work on ansible and bin directories

# process_ansible.sh
# process_bin.sh
# --------------------------

# List of directories and files to include in the tar archive
ITEMS_TO_ARCHIVE=(
  "debs-jammy.tar"
  "binaries.tar"
  "containers-adminhost"
  "containers-helm.tar"
  "containers-system.tar"
  "charts"
  "values"
  "../../../ansible"
  "../../../bin"
)

# Function to check if an item exists
check_item_exists() {
  local item=$1
  if [[ ! -e "$item" ]]; then
    echo "Error: $item does not exist."
    exit 1
  fi
}

cd "$OUTPUT_DIR" || { echo "Error: Cannot change to directory $OUTPUT_DIR"; exit 1; }

for item in "${ITEMS_TO_ARCHIVE[@]}"; do
  check_item_exists "$item"
done

# Create the tar archive with relative paths
tar czf "$OUTPUT_TAR" "${ITEMS_TO_ARCHIVE[@]}"
echo "Done"
