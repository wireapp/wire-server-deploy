#!/usr/bin/env bash
set -euo pipefail

if [[ ! $# -eq 2 ]]; then
  echo "usage: $0 OUTPUT_DIR PROFILE_OUT_DIR" >&2
  exit 1
fi

OUTPUT_DIR="$1"
PROFILE_OUT_DIR="$2"

echo "Running post-chart process script 1 in dir ${OUTPUT_DIR} from profile output dir ${PROFILE_OUT_DIR} ..."

containers_dir="${PROFILE_OUT_DIR}/containers-helm"
index_file="${containers_dir}"/index.txt
images_json_file="${PROFILE_OUT_DIR}/versions/containers_helm_images.json"
helm_image_tree_file="${PROFILE_OUT_DIR}/versions/helm_image_tree.json"

# this script is based on pre_processing of charts for optimization reasons
# assuming that path of federator image won't change or we need to re-process all the charts again
# just for safety will add a check if the federator image is not persent here, that will mark as indicator that path has changed
fed_docker_image="quay.io/wire/federator"
fed_image_tar_name=$(grep -i "$(echo ${fed_docker_image} | sed -r 's/[:\/]/_/g')" "${index_file}")

line_count=$(echo "${fed_image_tar_name}" | wc -l)

if [[ ${line_count} -ne 1 ]]; then
  echo "Federator image is not found in index file or multiple entries has been found. Exiting to confrim the new pattern of image ${fed_image_tar_name} and ${fed_docker_image} and if all the images should be processed"
  exit 1
fi

# moving the original files to a temp directory to recover the original state, in case it can be accessed by other profiles
temp_dir=$(mktemp -d -p "${containers_dir}")
cp "${index_file}" "${temp_dir}/index.txt"

mv "${containers_dir}/${fed_image_tar_name}" "${temp_dir}/"
# removing the federator image from the index file
sed -i "/${fed_image_tar_name}/d" "${index_file}"

# removing fed_image directly in the output_dir/versions/ for containers_helm_images.json and helm_image_tree.json file
jq --arg pattern "${fed_docker_image}" 'map( .images |= map(select(. | test($pattern) | not)))' "${helm_image_tree_file}" > "${OUTPUT_DIR}/versions/helm_image_tree.json"
jq --arg pattern "${fed_docker_image}" 'map( select(keys[0] | test($pattern) | not))' "${images_json_file}" > "${OUTPUT_DIR}/versions/containers_helm_images.json"

tar cf "${OUTPUT_DIR}"/containers-helm.tar -C "${containers_dir}/../" --exclude="$(basename "${temp_dir}")" containers-helm

# restoring the original state
mv "${temp_dir}/${fed_image_tar_name}" "${containers_dir}/"
mv "${temp_dir}/index.txt" "${index_file}"
rm -rf "${temp_dir}"
