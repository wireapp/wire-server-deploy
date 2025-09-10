#!/usr/bin/env bash
# This consumes a list of helm charts from stdin.
# It will invoke helm template on each of them, passing in values from our
# examples in values/, and obtain the list of container images for each of
# those.
# In cases where no container image tag has been specified, it'll use `latest`.
# The list is sorted and deduplicated, then printed to stdout.
set -eou pipefail

VALUES_DIR=""
HELM_IMAGE_TREE_FILE=""
VALUES_TYPE=""

# Parse the arguments
for arg in "$@"
do
  case $arg in
    VALUES_DIR=*)
      VALUES_DIR="${arg#*=}"
      ;;
    HELM_IMAGE_TREE_FILE=*)
      HELM_IMAGE_TREE_FILE="${arg#*=}"
      ;;
    VALUES_TYPE=*)
      VALUES_TYPE="${arg#*=}"
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$VALUES_DIR" || -z "$HELM_IMAGE_TREE_FILE" || -z "$VALUES_TYPE" ]]; then
  echo "Error: VALUES_DIR, HELM_IMAGE_TREE_FILE and VALUES_TYPE must be provided." >&2
  echo "Usage: $0 VALUES_DIR=<path> HELM_IMAGE_TREE_FILE=<file> [VALUES_TYPE=<type>]" >&2
  exit 1
fi

# create a dependency tree between helm chart and images
append_chart_entry() {
  local chart=$1
  local images=$2
  local json_file=$3

  if [ ! -f "$json_file" ]; then
    echo '[]' > "$json_file"
  fi

  existing_content=$(jq '.' "$json_file")
  new_entry=$(jq -n --arg chart "$chart" --argjson images "$images" '{"chart": $chart, "images": $images}')
  updated_content=$(echo "$existing_content" | jq --argjson new_entry "$new_entry" '. += [$new_entry]')
  echo "$updated_content" | jq '.' > "$json_file"
}

# Some of these images don't contain a "latest" tag. We don't to download /ALL/
# of them, but only :latest in that case - it's bad enough there's no proper
# versioning here.
function optionally_complain() {
  while IFS= read -r image; do
    if [[ $image =~ ":latest" ]]; then
      echo "Container $image with a latest tag found. Fix this chart. not compatible with offline. Components need explicit tags for that" >&2
    elif [[ $image =~ ":" ]]; then
      echo "$image"
    elif [[ $image =~ "@" ]]; then
      echo "$image"
    else
      echo "Container $image without a tag found or pin found. Aborting! Fix this chart. not compatible with offline. Components need explicit tags for that" >&2
      exit 1
    fi
  done
}

images=""
# For each helm chart passed in from stdin, use the example values to
# render the charts, and assemble the list of images this would fetch.
while IFS= read -r chart; do
  echo "Running helm template on chart ${chart}…" >&2
  current_images=$(helm template --debug "${chart}" \
    --set federate.dtls.tls.key=emptyString \
    --set federate.dtls.tls.crt=emptyString \
    $( [[ -f "${VALUES_DIR}"/$(basename "${chart}")/"${VALUES_TYPE}"-values.example.yaml ]] && echo "-f ${VALUES_DIR}/$(basename "${chart}")/${VALUES_TYPE}-values.example.yaml" ) \
    $( [[ -f "${VALUES_DIR}"/$(basename "${chart}")/"${VALUES_TYPE}"-secrets.example.yaml ]] && echo "-f ${VALUES_DIR}/$(basename "${chart}")/${VALUES_TYPE}-secrets.example.yaml" ) \
    | yq -r '..|.image? | select(.)' | optionally_complain | sort -u)

  images+="$current_images\n"
  if [[ -n "$current_images" ]]; then
    current_images=$(echo "$current_images" | awk NF)
    image_array=$(jq -Rn --arg images "$current_images" '$images | split("\n")')
    append_chart_entry "$(basename $chart)" "$image_array" "${HELM_IMAGE_TREE_FILE}"
  fi
done
echo -e "$images" | grep . | sort -u 
