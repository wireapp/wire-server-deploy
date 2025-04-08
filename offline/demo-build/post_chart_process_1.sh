#!/usr/bin/env bash
set -x -euo pipefail

if [[ ! $# -eq 2 ]]; then
  echo "usage: $0 OUTPUT_DIR PROFILE_OUT_DIR" >&2
  exit 1
fi

OUTPUT_DIR="$1"
PROFILE_OUT_DIR="$2"

echo "Running post-chart process script 1 in dir ${OUTPUT_DIR} from profile output dir ${PROFILE_OUT_DIR} ..."

containers_dir="${PROFILE_OUT_DIR}/containers-helm"
index_file="${containers_dir}"/index.txt
helm_image_tree_file="${PROFILE_OUT_DIR}/versions/helm_image_tree.txt"

# this script is based on pre_processing of charts for optimization reasons
# assuming that path of federator image won't change or we need to re-process all the charts again
# just for safety will add a check if the federator image is not persent here, that will mark as indicator that path has changed
fed_image_tar_name=$(grep -i "quay.io_wire_federator" "${index_file}")
fed_docker_image=$(grep -i "quay.io/wire/federator" "${helm_image_tree_file}")

line_count=$(echo "${fed_image_tar_name}" | wc -l)

if [[ ${line_count} -ne 1 ]]; then
  echo "Federator image is not found in index file or multiple entries has been found. Exiting to confrim the new pattern of image ${fed_image_tar_name}"
  exit 1
fi

# moving the original files to a temp directory to recover the original state, in case it can be accessed by other profiles
temp_dir=$(mktemp -d -p "${containers_dir}")
cp "${index_file}" "${temp_dir}/index.txt"

# creating a copy of previous output to 
cp "${helm_image_tree_file}" "${OUTPUT_DIR}/versions/helm_image_tree.txt"

mv "${containers_dir}/${fed_image_tar_name}" "${temp_dir}/"
# removing the federator image from the index file and helm_image_tree file
sed -i "/${fed_image_tar_name}/d" "${index_file}"
sed -i "/${fed_docker_image}/d" "${OUTPUT_DIR}/versions/helm_image_tree.txt"

tar cf "${OUTPUT_DIR}"/containers-helm.tar -C "${containers_dir}/../" --exclude="./containers-helm/$(basename "${temp_dir}")" containers-helm

# restoring the original state
mv "${temp_dir}/${fed_image_tar_name}" "${containers_dir}/"
mv "${temp_dir}/index.txt" "${index_file}"
rm -rf "${temp_dir}"
