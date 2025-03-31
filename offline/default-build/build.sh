#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# this directory will be created to store all the output files
OUTPUT_DIR="$SCRIPT_DIR/output"
# ROOT_DIR points to dir where ansible,bin, values etc can be located
# expected structure to be: /wire-server-deploy/offline/default-build/build.sh
# /wire-server-deploy/ansible
ROOT_DIR="${SCRIPT_DIR}/../../"

mkdir -p ${OUTPUT_DIR}/containers-{helm,other,system,adminhost} ${OUTPUT_DIR}/binaries

# Define the output tar file
OUTPUT_TAR="${OUTPUT_DIR}/assets.tgz"

TASKS_DIR="${SCRIPT_DIR}/../tasks"

# Any of the tasks can be skipped by commenting them out 
# however, mind the dependencies between them and how they are grouped

# Processing helm charts
# --------------------------

# pulling the charts, charts to be skipped are passed as arguments HELM_CHART_EXCLUDE_LIST
${TASKS_DIR}/proc_pull_charts.sh OUTPUT_DIR=$OUTPUT_DIR # HELM_CHART_EXCLUDE_LIST="inbucket,wire-server-enterprise,coturn"

# copy local copy of values from root directory to output directory
cp -r ${ROOT_DIR}/values ${OUTPUT_DIR}/

# all basic chart pre-processing tasks
${TASKS_DIR}/pre_chart_process_0.sh $OUTPUT_DIR

# all extra pre chart processing tasks for this profile should come here
# pre_chart_process_1.sh 
# pre_chart_process_2.sh 

# processing the charts
# here we also filter the images post processing the helm charts
# pass the image names to be filtered as arguments as regex #IMAGE_EXCLUDE_LIST='brig|galley'
${TASKS_DIR}/process_charts.sh OUTPUT_DIR=$OUTPUT_DIR #IMAGE_EXCLUDE_LIST=""

# all basic chart pre-processing tasks
${TASKS_DIR}/post_chart_process_0.sh $OUTPUT_DIR

# all extra post chart processing tasks for this profile should come here
# post_chart_process_1.sh
# post_chart_process_2.sh

# --------------------------

# Following tasks are independent from each other
# --------------------------

# building admin host containers, has dependenct on the helm charts
${TASKS_DIR}/build_adminhost_containers.sh $OUTPUT_DIR

# build linux packages
${TASKS_DIR}/build_linux_pkgs.sh $OUTPUT_DIR $ROOT_DIR

# Creating system containers tarball
${TASKS_DIR}/proc_system_containers.sh $OUTPUT_DIR

# Processing wire binaries
${TASKS_DIR}/proc_wire_binaries.sh $OUTPUT_DIR
# --------------------------

# custom scripts to work on ansible and bin directories

# process_ansible.sh
# process_bin.sh
# --------------------------

# for optmization purposes, if these tarballs are already processed by previous profiles check wire-server-deploy/.github/workflows/offline.yml, one can specify those paths as well <profile_dir>/output/containers-helm.tar <profile_dir>/output/containers-system.tar in the ITEMS_TO_ARCHIVE list below and skip the processing above accordingly

# List of directories and files to include in the tar archive
ITEMS_TO_ARCHIVE=(
  "${OUTPUT_DIR}/debs-jammy.tar"
  "${OUTPUT_DIR}/binaries.tar"
  "${OUTPUT_DIR}/containers-adminhost"
  "${OUTPUT_DIR}/containers-helm.tar"
  "${OUTPUT_DIR}/containers-system.tar"
  "${OUTPUT_DIR}/charts"
  "${OUTPUT_DIR}/values"
  "${ROOT_DIR}/ansible"
  "${ROOT_DIR}/bin"
)

check_item_exists() {
  local item=$1
  if [[ ! -e "$item" ]]; then
    echo "Error: $item does not exist."
    exit 1
  fi
}

for item in "${ITEMS_TO_ARCHIVE[@]}"; do
  check_item_exists "$item"
done

tar czf "$OUTPUT_TAR" "${ITEMS_TO_ARCHIVE[@]}"

echo "Done"
