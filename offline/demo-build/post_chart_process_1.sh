#!/usr/bin/env bash
set -euo pipefail

if [[ ! $# -eq 1 ]]; then
  echo "usage: $0 OUTPUT_DIR" >&2
  exit 1
fi

OUTPUT_DIR="$1"

echo "Running post-chart process script 1 in dir ${OUTPUT_DIR} ..."

containers_dir="${OUTPUT_DIR}"/containers-helm
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

rm -f "${containers_dir}/${fed_image}"
# removing the federator image from the index file and helm_image_tree file
sed -i "/${fed_image}/d" "${index_file}"
sed -i "/${fed_image}/d" "${helm_image_tree_file}"

