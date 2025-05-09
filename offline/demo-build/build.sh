#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# this directory will be created to store all the output files
OUTPUT_DIR="$SCRIPT_DIR/output"
# ROOT_DIR points to dir where ansible,bin, values etc can be located
# expected structure to be: /wire-server-deploy/offline/default-build/build.sh
ROOT_DIR="${SCRIPT_DIR}/../../"

mkdir -p "${OUTPUT_DIR}"/containers-{helm,other,system,adminhost} "${OUTPUT_DIR}"/binaries "${OUTPUT_DIR}"/versions

# Define the output tar file
OUTPUT_TAR="${OUTPUT_DIR}/assets.tgz"

# for optmization purposes, if these tarballs are already processed by previous profiles check wire-server-deploy/.github/workflows/offline.yml, one can copy those artifacts from previous profiles to your profile by using
#cp $SCRIPT_DIR/../<profile-dir>/output/containers-helm.tar "${OUTPUT_DIR}"/
# one need to comment the tasks below for which one wants to optimize the build
SOURCE_OUTPUT_DIR="${SCRIPT_DIR}/../default-build/output"

# Any of the tasks can be skipped by commenting them out 
# however, mind the dependencies between them and how they are grouped

# Processing helm charts
# --------------------------

# pulling the charts, charts to be skipped are passed as arguments HELM_CHART_EXCLUDE_LIST
"${TASKS_DIR}"/proc_pull_charts.sh OUTPUT_DIR="${OUTPUT_DIR}" HELM_CHART_EXCLUDE_LIST="inbucket,wire-server-enterprise,k8ssandra-operator,k8ssandra-test-cluster,elasticsearch-curator,postgresql,keycloakx,openebs,nginx-ingress-controller,kibana,restund,fluent-bit,aws-ingress,redis-cluster,calling-test"

# copy local copy of values from root directory to output directory
cp -r "${ROOT_DIR}"/values "${OUTPUT_DIR}"/

# removing the values/$chart directories in values directory if not required
"${TASKS_DIR}"/pre_clean_values_0.sh VALUES_DIR="${OUTPUT_DIR}/values" HELM_CHART_EXCLUDE_LIST="inbucket,wire-server-enterprise,k8ssandra-operator,k8ssandra-test-cluster,elasticsearch-curator,postgresql,keycloakx,openebs,nginx-ingress-controller,kibana,restund,fluent-bit,aws-ingress,redis-cluster,calling-test"

# processing the charts
# here we also filter the images post processing the helm charts
# pass the image names to be filtered as arguments as regex #IMAGE_EXCLUDE_LIST='brig|galley'
"${TASKS_DIR}"/process_charts.sh OUTPUT_DIR="${OUTPUT_DIR}" IMAGE_EXCLUDE_LIST="quay.io/wire/federator"

# all basic chart pre-processing tasks
"${TASKS_DIR}"/post_chart_process_0.sh "${OUTPUT_DIR}"

# copying charts from the default build
#cp -r "${SOURCE_OUTPUT_DIR}/charts" "${OUTPUT_DIR}/"

# copy values from the default build
#cp -r "${SOURCE_OUTPUT_DIR}/values" "${OUTPUT_DIR}/"

# here removing the federation image from cintainers-helm directory
#"${SCRIPT_DIR}"/post_chart_process_1.sh "${OUTPUT_DIR}"/ "${SCRIPT_DIR}/../default-build/output"
# --------------------------

# Following tasks are independent from each other
# linking the output from the SOURCE_OUTPUT_DIR to the OUTPUT_DIR to confirm if they exist
# --------------------------

# linking containers-adminhost directory from the default build
ln -sf "${SOURCE_OUTPUT_DIR}/containers-adminhost" "${OUTPUT_DIR}/containers-adminhost"

# link debs-jammy.tar from the default build
# ln -sf "${SOURCE_OUTPUT_DIR}/debs-jammy.tar" "${OUTPUT_DIR}/debs-jammy.tar"

# link containers-system.tar from the default build
# ln -sf "${SOURCE_OUTPUT_DIR}/containers-system.tar" "${OUTPUT_DIR}/containers-system.tar"

# copy binaries.tar from the default build
# ln -sf "${SOURCE_OUTPUT_DIR}/binaries.tar" "${OUTPUT_DIR}/binaries.tar"

#cp "${SOURCE_OUTPUT_DIR}/versions/wire-binaries.json" "${OUTPUT_DIR}/versions/"
#cp "${SOURCE_OUTPUT_DIR}/versions/debian-builds.json" "${OUTPUT_DIR}/versions/"
cp "${SOURCE_OUTPUT_DIR}/versions/containers_adminhost_images.json" "${OUTPUT_DIR}/versions/"
#cp "${SOURCE_OUTPUT_DIR}/versions/containers_system_images.json" "${OUTPUT_DIR}/versions/"

# --------------------------

# List of directories and files to include in the tar archive
ITEMS_TO_ARCHIVE=(
  "containers-adminhost"
  "containers-helm.tar"
  "charts"
  "values"
  "../../../bin"
  "versions"
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
# for the outputs from other other profiles, their paths should be mentioned here
tar czf "$OUTPUT_TAR" \
  -C "${SOURCE_OUTPUT_DIR}" containers-adminhost \
  -C "${ROOT_DIR}" bin \
  -C "${OUTPUT_DIR}" charts values versions containers-helm.tar
