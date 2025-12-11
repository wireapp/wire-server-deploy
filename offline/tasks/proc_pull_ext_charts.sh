#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR=""
HELM_CHART_INCLUDE_JSON=""

# Parse the arguments
for arg in "$@"
do
  case $arg in
    OUTPUT_DIR=*)
      OUTPUT_DIR="${arg#*=}"
      ;;
    HELM_CHART_INCLUDE_JSON=*)
      HELM_CHART_INCLUDE_JSON="${arg#*=}"
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

# Check if args are set
if [[ -z "$OUTPUT_DIR" ]] || [[ -z "$HELM_CHART_INCLUDE_JSON" ]]; then
  echo "usage: $0 OUTPUT_DIR=\"output-dir\" HELM_CHART_INCLUDE_JSON=\"path/to/charts.json\"" >&2
  exit 1
fi

# Check if JSON file exists
if [[ ! -f "$HELM_CHART_INCLUDE_JSON" ]]; then
  echo "Error: JSON file not found: $HELM_CHART_INCLUDE_JSON" >&2
  exit 1
fi

echo "Pulling Helm charts in $OUTPUT_DIR"
echo "Using chart configuration from: $HELM_CHART_INCLUDE_JSON"

# Extract charts from JSON file in format: <chart-name> <repo-url> <chart-version>
extract_charts() {
  jq -r '.helmCharts | to_entries | map("\(.key) \(.value.repo) \(.value.version)") | join("\n")' "$HELM_CHART_INCLUDE_JSON" 2>/dev/null
  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to parse JSON file. Expected format: {\"helmCharts\": {\"chart-name\": {\"repo\": \"url\", \"version\": \"version\"}, ...}}" >&2
    exit 1
  fi
}

# pull_charts() accepts charts in format
# <chart-name> <repo-url> <chart-version>
# on stdin
pull_charts() {
  echo "Pulling charts into ${OUTPUT_DIR}/charts ..."
  mkdir -p "${OUTPUT_DIR}"/charts

  home=$(mktemp -d)
  export HELM_CACHE_HOME="$home"
  export HELM_DATA_HOME="$home"
  export HELM_CONFIG_HOME="$home"

  declare -A repos
  # needed to handle associative array lookup
  set +u

  while IFS=$'\n' read -r line
  do
    echo "$line"
    IFS=$' ' read -r -a parts <<< "$line"
    name=${parts[0]}
    repo=${parts[1]}
    version=${parts[2]}

    # we add and update the repo only the first time we see it to speed up the process
    repo_short_name=${repos[$repo]}
    if [ "$repo_short_name" == "" ]; then
      n=${#repos[@]}
      repo_short_name="repo_$((n+1))"
      repos[$repo]=$repo_short_name
      helm repo add "$repo_short_name" "$repo"
      helm repo update "$repo_short_name"
    fi
    (cd "${OUTPUT_DIR}"/charts; helm pull --version "$version" --untar "$repo_short_name/$name")
  done
  
  # Cleanup temporary helm home
  rm -rf "$home"
  echo "Pulling charts done."
}

extract_charts | pull_charts
