#!/usr/bin/env bash
# shellcheck disable=SC2190
set -euo pipefail

OUTPUT_DIR=""
# build.json to source chart versions from; override with WIRE_BUILD=<url>
WIRE_BUILD="https://raw.githubusercontent.com/wireapp/wire-builds/refs/heads/2026-q4-from-rm/build.json"
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
    WIRE_BUILD=*)
      WIRE_BUILD="${arg#*=}"
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

# Check if OUTPUT_DIR is set
if [[ -z "$OUTPUT_DIR" ]]; then
  echo "usage: $0 OUTPUT_DIR=\"output-dir\" [HELM_CHART_EXCLUDE_LIST=\"chart1,chart2,...\"] [WIRE_BUILD=\"build.json-url\"]" >&2
  exit 1
fi

echo "Pulling Helm charts in $OUTPUT_DIR"

HELM_CHART_EXCLUDE_LIST=$(echo "$HELM_CHART_EXCLUDE_LIST" | jq -R 'split(",")')
echo "Excluding following charts from the release: $HELM_CHART_EXCLUDE_LIST"

wire_build_chart_release () {

  wire_build="$1"
  curl "$wire_build" -o "${OUTPUT_DIR}/build.json"
  jq -r --argjson HELM_CHART_EXCLUDE_LIST "$HELM_CHART_EXCLUDE_LIST" '
  .helmCharts
  | with_entries(select(.key as $k | $HELM_CHART_EXCLUDE_LIST | index($k) | not))
  | to_entries
  | map("\(.key) \(.value.repo) \(.value.version)")
  | join("\n")
  ' "${OUTPUT_DIR}/build.json"
}

# Log in to an OCI registry once, if credentials are available
# (OCI_REGISTRY_USERNAME / OCI_REGISTRY_PASSWORD). Public charts are pulled
# anonymously when no credentials are set.
declare -A registry_logged_in
oci_registry_login() {
  local registry="$1"
  if [[ -n "${registry_logged_in[$registry]}" || -z "${OCI_REGISTRY_USERNAME:-}" ]]; then
    return 0
  fi
  echo "Logging in to OCI registry $registry as $OCI_REGISTRY_USERNAME"
  helm registry login "$registry" --username "$OCI_REGISTRY_USERNAME" --password-stdin <<< "${OCI_REGISTRY_PASSWORD:?OCI_REGISTRY_PASSWORD must be set}"
  registry_logged_in[$registry]=1
}

# pull_charts() accepts charts in format
# <chart-name> <repo-url> <chart-version>
# on stdin.
# For OCI charts, <repo-url> is the full chart reference
# (e.g. oci://quay.io/wire/charts/dev/wire-server), whose last path segment
# may differ from <chart-name> (e.g. webapp -> wire-webapp).
# Every chart is extracted to ${OUTPUT_DIR}/charts/<chart-name>.
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
      # OCI charts are pulled directly by reference, no helm repo add needed
      registry=${repo#oci://}
      oci_registry_login "${registry%%/*}"
      chart_ref="$repo"
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
      chart_ref="$repo_short_name/$name"
    fi

    # untar into a scratch dir, then move to charts/<name> so the layout does
    # not depend on the chart's own name
    untar_dir=$(mktemp -d)
    helm pull --version "$version" --untar --untardir "$untar_dir" "$chart_ref"
    rm -rf "${OUTPUT_DIR:?}/charts/${name}"
    mv "$untar_dir"/* "${OUTPUT_DIR}/charts/${name}"
    rm -rf "$untar_dir"
  done
  echo "Pulling charts done."

}

wire_build_chart_release "$WIRE_BUILD" | pull_charts
