#!/usr/bin/env bash
set -euo pipefail

# Default output dir
OUTPUT_DIR=""
# Default values type will expect to use prod values
VALUES_TYPE="prod"

# Parse the arguments
for arg in "$@"
do
  case $arg in
    OUTPUT_DIR=*)
      OUTPUT_DIR="${arg#*=}"
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


# Check if OUTPUT_DIR is set
if [[ -z "$OUTPUT_DIR" ]]; then
  echo "usage: $0 OUTPUT_DIR=\"values-dir\" [VALUES_TYPE=\"prod|demo\"]" >&2
  exit 1
fi

echo "Running post-chart process script 0 in dir $OUTPUT_DIR with values type $VALUES_TYPE"

# Undo changes on wire-server values.yaml
sed -i -Ee 's/useSharedFederatorSecret: true/useSharedFederatorSecret: false/' "${OUTPUT_DIR}/charts/wire-server/charts/federator/values.yaml"
sed -i -Ee 's/federation: true/federation: false/' "${OUTPUT_DIR}/values/wire-server/${VALUES_TYPE}-values.example.yaml"

# cleanup wire-utility chart values
rm -rf "${OUTPUT_DIR}/values/wire-utility/"
