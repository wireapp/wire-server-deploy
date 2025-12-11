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

TASKS_DIR="${SCRIPT_DIR}/../tasks"

# Any of the tasks can be skipped by commenting them out 
# however, mind the dependencies between them and how they are grouped

# Processing helm charts
# --------------------------
HELM_CHART_EXCLUDE_LIST="inbucket,wire-server-enterprise,k8ssandra-operator,k8ssandra-test-cluster,elasticsearch-curator,keycloakx,openebs,nginx-ingress-controller,kibana,restund,fluent-bit,aws-ingress,redis-cluster,calling-test,cassandra-external,elasticsearch-external,minio-external,postgresql-external,rabbitmq-external"

# pulling the charts, charts to be skipped are passed as arguments HELM_CHART_EXCLUDE_LIST
"${TASKS_DIR}"/proc_pull_charts.sh OUTPUT_DIR="${OUTPUT_DIR}" HELM_CHART_EXCLUDE_LIST="${HELM_CHART_EXCLUDE_LIST}"

#  cleaning some charts which aren't required from wire_builds, these should be pulled in the next step
rm -rf "${OUTPUT_DIR}/charts/coturn"
rm -rf "${OUTPUT_DIR}/charts/sftd"
rm -rf "${OUTPUT_DIR}/charts/reaper"

# pulling the charts which are not present in wire_builds json file
"${TASKS_DIR}"/proc_pull_ext_charts.sh OUTPUT_DIR="${OUTPUT_DIR}" HELM_CHART_INCLUDE_JSON="${SCRIPT_DIR}/extra_charts.json"

# copy local copy of values from root directory to output directory
cp -r "${ROOT_DIR}"/values "${OUTPUT_DIR}"/

# copy local copy of dashboards from root directory to output directory
cp -r "${ROOT_DIR}"/dashboards "${OUTPUT_DIR}"/

# copy offline-env.sh to bin directory in output
mkdir "${OUTPUT_DIR}/bin"
cp "${ROOT_DIR}/bin/offline-env-wiab.sh" "${OUTPUT_DIR}/bin/"

# removing the values/$chart directories in values directory if not required
"${TASKS_DIR}"/pre_clean_values_0.sh VALUES_DIR="${OUTPUT_DIR}/values" HELM_VALUES_EXCLUDE_LIST="${HELM_CHART_EXCLUDE_LIST}" VALUES_TYPE="demo"

# all basic chart pre-processing tasks
"${TASKS_DIR}"/pre_chart_process_0.sh OUTPUT_DIR="${OUTPUT_DIR}" VALUES_TYPE="demo"

# processing the charts
# here we also filter the images post processing the helm charts
# pass the image names to be filtered as arguments as regex #IMAGE_EXCLUDE_LIST='brig|galley'
"${TASKS_DIR}"/process_charts.sh OUTPUT_DIR="${OUTPUT_DIR}" IMAGE_EXCLUDE_LIST="quay.io/wire/federator" VALUES_TYPE="demo"

# all basic chart pre-processing tasks
"${TASKS_DIR}"/post_chart_process_0.sh OUTPUT_DIR="${OUTPUT_DIR}" VALUES_TYPE="demo"

# --------------------------
# building admin host containers, has dependency on the helm charts
"${TASKS_DIR}"/build_adminhost_containers.sh "${OUTPUT_DIR}" --adminhost

# --------------------------

# List of directories and files to include in the tar archive
ITEMS_TO_ARCHIVE=(
  "containers-adminhost"
  "containers-helm.tar"
  "charts"
  "values"
  "bin"
  "versions"
  "dashboards"
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
