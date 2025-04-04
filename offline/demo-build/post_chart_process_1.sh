#!/usr/bin/env bash
set -x -euo pipefail

if [[ ! $# -eq 2 ]]; then
  echo "usage: $0 OUTPUT_DIR CONTAINERS_HELM_DIR" >&2
  exit 1
fi

OUTPUT_DIR="$1"
CONTAINERS_HELM_DIR="$2"

echo "Running post-chart process script 1 in dir ${OUTPUT_DIR} with containers_helm_dir ${CONTAINERS_HELM_DIR} ..."

containers_dir="${CONTAINERS_HELM_DIR}"/containers-helm
index_file="${containers_dir}"/index.txt
helm_image_tree_file="${containers_dir}"/helm_image_tree.txt

# this script is based on pre_processing of charts for optimization reasons
# assuming that path of federator image won't change or we need to re-process all the charts again
# just for safety will add a check if the federator image is not persent here, that will mark as indicator that path has changed
fed_image=$(grep -i "quay.io_wire_federator" "${index_file}")

if [[ -z "${fed_image}" ]]; then
  echo "Federator image not found in index file. Exiting to confrim the new pattern of image"
  exit 1
fi

# moving the original files to a temp directory to recover the original state, in case it can be accessed by other profiles
temp_dir=$(mktemp -d -p "${CONTAINERS_HELM_DIR}")
cp "${index_file}" "${temp_dir}/index.txt"
cp "${helm_image_tree_file}" "${temp_dir}/helm_image_tree.txt"

mv "${containers_dir}/${fed_image}" "${temp_dir}/"
# removing the federator image from the index file and helm_image_tree file
sed -i "/${fed_image}/d" "${index_file}"
sed -i "/${fed_image}/d" "${helm_image_tree_file}"

tar cf "${OUTPUT_DIR}"/containers-helm.tar -C "./containers-helm/${CONTAINERS_HELM_DIR}/.." --exclude="./$(basename "${temp_dir}")" containers-helm

# restoring the original state
mv "${temp_dir}/${fed_image}" "${containers_dir}/"
mv "${temp_dir}/index.txt" "${index_file}"
mv "${temp_dir}/helm_image_tree.txt" "${helm_image_tree_file}"
rm -rf "${temp_dir}"
