#!/usr/bin/env bash
set -euo pipefail

HELM_CHARTS_REPO="https://github.com/wireapp/helm-charts.git"
OUTPUT_DIR=""

# Parse the arguments
for arg in "$@"
do
  case $arg in
    OUTPUT_DIR=*)
      OUTPUT_DIR="${arg#*=}"
      ;;
    HELM_CHART_INCLUDE_LIST=*)
      HELM_CHART_INCLUDE_LIST="${arg#*=}"
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

# Check if args are set
if [[ -z "$OUTPUT_DIR" ]] || [[ -z "$HELM_CHART_INCLUDE_LIST" ]]; then
  echo "usage: $0 OUTPUT_DIR=\"output-dir\" [HELM_CHART_INCLUDE_LIST=\"chart1,chart2,...\"]" >&2
  exit 1
fi

echo "Pulling Helm charts in $OUTPUT_DIR"
echo "Including following charts from the repo: $HELM_CHART_INCLUDE_LIST"

copy_charts() {
  echo "Pulling charts into ${OUTPUT_DIR}/charts ..."
  if [[ ! -d "${OUTPUT_DIR}/charts" ]]; then
    mkdir -p "${OUTPUT_DIR}/charts"
  fi
  temp_dir=$(mktemp -d)
  git clone --depth 1 "$HELM_CHARTS_REPO" "$temp_dir"

  IFS=',' read -ra CHARTS <<< "$HELM_CHART_INCLUDE_LIST"
  for chart in "${CHARTS[@]}"; do
    if [[ -d "$temp_dir/charts/${chart}" ]]; then
      echo "Copying chart: $chart"
      cp -r "$temp_dir/charts/${chart}" "${OUTPUT_DIR}/charts"
    else
      echo "Chart $chart not found in the repository." >&2
    fi
  done
}

copy_charts
