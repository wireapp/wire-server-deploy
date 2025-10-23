#!/usr/bin/env bash
# This consumes a list of helm charts from stdin.
# It will invoke helm template on each of them, passing in values from our
# examples in values/, and obtain the list of container images for each of
# those.
# In cases where no container image tag has been specified, it'll use `latest`.
# The list is sorted and deduplicated, then printed to stdout.
set -euo pipefail

VALUES_DIR=""
HELM_IMAGE_TREE_FILE=""
VALUES_TYPE=""

# Extract images using yq-go (v4+) syntax
# Note: This requires yq-go to be in PATH (see default.nix)
extract_images() {
  yq eval '.. | select(has("image")) | .image' "$1" 2>/dev/null || true
}

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
chart_count=0
while IFS= read -r chart; do
  chart_count=$((chart_count + 1))
  echo "[$chart_count] Running helm template on chart ${chart}…" >&2
  set +e  # Temporarily disable exit on error
  # Determine values file to use (prod first, then demo as fallback)
  values_file=""
  if [[ -f "${VALUES_DIR}"/$(basename "${chart}")/"${VALUES_TYPE}"-values.example.yaml ]]; then
    values_file="${VALUES_DIR}/$(basename "${chart}")/${VALUES_TYPE}-values.example.yaml"
  elif [[ -f "${VALUES_DIR}"/$(basename "${chart}")/demo-values.example.yaml ]]; then
    values_file="${VALUES_DIR}/$(basename "${chart}")/demo-values.example.yaml"
    echo "Using demo values for $(basename $chart) (no ${VALUES_TYPE} values found)" >&2
  fi

  # Determine secrets file to use
  secrets_file=""
  if [[ -f "${VALUES_DIR}"/$(basename "${chart}")/"${VALUES_TYPE}"-secrets.example.yaml ]]; then
    secrets_file="${VALUES_DIR}/$(basename "${chart}")/${VALUES_TYPE}-secrets.example.yaml"
  elif [[ -f "${VALUES_DIR}"/$(basename "${chart}")/demo-secrets.example.yaml ]]; then
    secrets_file="${VALUES_DIR}/$(basename "${chart}")/demo-secrets.example.yaml"
  fi

  # Separate helm stderr from stdout to avoid yq parsing errors
  # Save helm output to temp file to capture exit code
  temp_helm_output=$(mktemp)
  helm template "${chart}" \
    $( [[ -n "$values_file" ]] && echo "-f $values_file" ) \
    $( [[ -n "$secrets_file" ]] && echo "-f $secrets_file" ) \
    > "$temp_helm_output" 2>&1

  helm_exit_code=$?

  # Extract images using version-appropriate yq syntax
  if [[ $helm_exit_code -eq 0 ]]; then
    raw_images=$(extract_images "$temp_helm_output" | grep -v "^null$" | grep -v "^---$" | grep -v "^$" || true)
  else
    raw_images=""
  fi

  rm -f "$temp_helm_output"
  set -e  # Re-enable exit on error

  if [[ $helm_exit_code -ne 0 ]]; then
    echo "ERROR: Failed to process chart $(basename $chart)" >&2
    echo "Chart path: $chart" >&2
    echo "Values file: ${values_file:-none}" >&2
    echo "Secrets file: ${secrets_file:-none}" >&2
    echo "Try running: helm template $chart $([ -n "$values_file" ] && echo "-f $values_file") $([ -n "$secrets_file" ] && echo "-f $secrets_file")" >&2
    raw_images=""
  fi

  # Process extracted images
  if [[ -n "$raw_images" ]]; then
    current_images=$(echo "$raw_images" | grep -v "^$" | optionally_complain | sort -u)
  else
    current_images=""
  fi

  images+="$current_images\n"
  if [[ -n "$current_images" ]]; then
    current_images=$(echo "$current_images" | awk NF)
    image_array=$(jq -Rn --arg images "$current_images" '$images | split("\n")')
    append_chart_entry "$(basename $chart)" "$image_array" "${HELM_IMAGE_TREE_FILE}"
  fi
done
echo -e "$images" | grep . | sort -u || true
