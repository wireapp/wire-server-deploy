#!/usr/bin/env bash
set -x -euo pipefail

# Default exclude list
VALUES_DIR=""
HELM_CHART_EXCLUDE_LIST="inbucket,wire-server-enterprise"

# Parse the arguments
for arg in "$@"
do
  case $arg in
    VALUES_DIR=*)
      VALUES_DIR="${arg#*=}"
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
if [[ -z "$VALUES_DIR" ]]; then
  echo "usage: $0 VALUES_DIR=\"values-dir\" [HELM_CHART_EXCLUDE_LIST=\"chart1,chart2,...\"]" >&2
  exit 1
fi

echo "Running pre-clean values process script 1 in dir $VALUES_DIR ..."

# Split the HELM_CHART_EXCLUDE_LIST into an array
IFS=',' read -r -a EXCLUDE_ARRAY <<< "$HELM_CHART_EXCLUDE_LIST"

# Iterate over each chart in the exclude list
for CHART in "${EXCLUDE_ARRAY[@]}"; do
  CHART_DIR="$VALUES_DIR/$CHART"
  if [[ -d "$CHART_DIR" ]]; then
    echo "Removing values directory: $CHART_DIR"
    rm -rf "$CHART_DIR"
  fi
done 
