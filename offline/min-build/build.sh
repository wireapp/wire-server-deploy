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

# pulling the charts, charts to be skipped are passed as arguments HELM_CHART_EXCLUDE_LIST
"${TASKS_DIR}"/proc_pull_charts.sh OUTPUT_DIR="${OUTPUT_DIR}" HELM_CHART_EXCLUDE_LIST="inbucket,wire-server-enterprise,k8ssandra-operator,k8ssandra-test-cluster,elasticsearch-ephemeral,elasticsearch-curator,rabbitmq,demo-smtp,fake-aws,fake-aws-s3,fake-aws-sqs,postgresql,keycloakx,openebs"

# optionally if we want to remove the following
# smallstep-accomp,step-certificates,reaper,redis-cluster,redis-ephemeral

# copy local copy of values from root directory to output directory
cp -r "${ROOT_DIR}"/values "${OUTPUT_DIR}"/

# removing the values/$chart directories in values directory if not required
pre_clean_values_1.sh VALUES_DIR="${OUTPUT_DIR}/values" HELM_CHART_EXCLUDE_LIST="inbucket,wire-server-enterprise,k8ssandra-operator,k8ssandra-test-cluster,elasticsearch-ephemeral,elasticsearch-curator,rabbitmq,demo-smtp,fake-aws,fake-aws-s3,fake-aws-sqs,postgresql,keycloakx,openebs"

# all basic chart pre-processing tasks
"${TASKS_DIR}"/pre_chart_process_0.sh "${OUTPUT_DIR}"

# all extra pre chart processing tasks for this profile should come here
# pre_chart_process_1.sh
# pre_chart_process_2.sh 

# processing the charts
# here we also filter the images post processing the helm charts
# pass the image names to be filtered as arguments as regex #IMAGE_EXCLUDE_LIST='brig|galley'
"${TASKS_DIR}"/process_charts.sh OUTPUT_DIR="${OUTPUT_DIR}" #IMAGE_EXCLUDE_LIST=""

# all basic chart pre-processing tasks
"${TASKS_DIR}"/post_chart_process_0.sh "${OUTPUT_DIR}"

# all extra post chart processing tasks for this profile should come here
# post_chart_process_1.sh
# post_chart_process_2.sh

# --------------------------

# Following tasks are independent from each other
# --------------------------

# building admin host containers, has dependenct on the helm charts
"${TASKS_DIR}"/build_adminhost_containers.sh "${OUTPUT_DIR}"

# --------------------------

# List of directories and files to include in the tar archive
ITEMS_TO_ARCHIVE=(
  "containers-adminhost"
  "containers-helm.tar"
  "charts"
  "values"
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
