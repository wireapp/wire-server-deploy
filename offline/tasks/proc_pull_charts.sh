#!/usr/bin/env bash
# shellcheck disable=SC2190
set -euo pipefail

OUTPUT_DIR=""
# Default exclude lists
HELM_CHART_EXCLUDE_LIST="inbucket,wire-server-enterprise,demo-smtp"

# Parse the arguments
for arg in "$@"
do
  case $arg in
    OUTPUT_DIR=*)
      OUTPUT_DIR="${arg#*=}"
      ;;
    HELM_CHART_EXCLUDE_LIST=*)
      HELM_CHART_EXCLUDE_LIST="${arg#*=}"
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

# Check if OUTPUT_DIR is set
if [[ -z "$OUTPUT_DIR" ]]; then
  echo "usage: $0 OUTPUT_DIR=\"output-dir\" [HELM_CHART_EXCLUDE_LIST=\"chart1,chart2,...\"]" >&2
  exit 1
fi

echo "Pulling Helm charts in $OUTPUT_DIR"

HELM_CHART_EXCLUDE_LIST=$(echo "$HELM_CHART_EXCLUDE_LIST" | jq -R 'split(",")')
echo "Excluding following charts from the release: $HELM_CHART_EXCLUDE_LIST"

wire_build_chart_release () {

  wire_build="$1"
  curl "$wire_build" | jq -r --argjson HELM_CHART_EXCLUDE_LIST "$HELM_CHART_EXCLUDE_LIST" '
  .helmCharts
  | with_entries(select(.key as $k | $HELM_CHART_EXCLUDE_LIST | index($k) | not))
  | to_entries
  | map("\(.key) \(.value.repo) \(.value.version)")
  | join("\n")
  '
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

    if [[ "$repo" == oci://* ]]; then
      # OCI repos are pulled directly, no helm repo add needed
      (cd "${OUTPUT_DIR}"/charts; helm pull --version "$version" --untar "$repo/$name")
    else
      # For traditional repos, add and update only on first encounter
      repo_short_name=${repos[$repo]}
      if [ "$repo_short_name" == "" ]; then
        n=${#repos[@]}
        repo_short_name="repo_$((n+1))"
        repos[$repo]=$repo_short_name
        helm repo add "$repo_short_name" "$repo"
        helm repo update "$repo_short_name"
      fi
      (cd "${OUTPUT_DIR}"/charts; helm pull --version "$version" --untar "$repo_short_name/$name")
    fi
  done
  echo "Pulling charts done."

}

wire_build="https://raw.githubusercontent.com/wireapp/wire-builds/49150536aa00a5f23b3d1a44f0f461c41b4d8834/build.json"
wire_build_chart_release "$wire_build" | pull_charts
