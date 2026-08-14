#!/usr/bin/env bash
set -x -euo pipefail

OUTPUT_DIR=""
CHART_LINK=""

# Parse the arguments
for arg in "$@"
do
  case $arg in
    OUTPUT_DIR=*)
      OUTPUT_DIR="${arg#*=}"
      ;;
    CHART_LINK=*)
      CHART_LINK="${arg#*=}"
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

# Check if OUTPUT_DIR is set
if [[ -z "$OUTPUT_DIR" ]] || [[ -z "$CHART_LINK" ]] ; then
  echo "usage: $0 OUTPUT_DIR=\"output-dir\" CHART_LINK=\CHART_LINK\"" >&2
  exit 1
fi

echo "Pulling Helm charts in $OUTPUT_DIR using $CHART_LINK"

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

    (cd "${OUTPUT_DIR}"/charts; helm pull --untar "$repo:$version" && rm -rf $name:$version)
  done
  echo "Pulling charts done."
}

manifest_chart_release () {

  manifest_file="$1"
  yq -r '
  .artifacts[]
  | select(.kind == "helm-chart")
  | [.name, .repository, .tag]
  | join(" ")
  ' "${manifest_file}"
}

pull_oci_artifact(){
  oras pull ${CHART_LINK} --output ${OUTPUT_DIR}

  ARTIFACT=$(oras manifest fetch "${CHART_LINK}" \
  | jq -r '.layers[0].annotations["org.opencontainers.image.title"]')

  ls -lh "${OUTPUT_DIR}/${ARTIFACT}"

  tar -xzf "${OUTPUT_DIR}/${ARTIFACT}" -C "$OUTPUT_DIR"
}

pull_oci_artifact

manifest_chart_release "${OUTPUT_DIR}/manifest.yaml" | pull_charts
