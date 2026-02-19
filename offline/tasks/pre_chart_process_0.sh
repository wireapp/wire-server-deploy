#!/usr/bin/env bash
set -exuo pipefail

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

echo "Running pre-chart process script 0 in dir $OUTPUT_DIR with values type $VALUES_TYPE"

# Patch wire-server values.yaml to include federator
# This is needed to bundle it's image.
sed -i -Ee 's/federation: false/federation: true/' "${OUTPUT_DIR}/values/wire-server/${VALUES_TYPE}-values.example.yaml"
sed -i -Ee 's/useSharedFederatorSecret: false/useSharedFederatorSecret: true/' "${OUTPUT_DIR}"/charts/wire-server/charts/federator/values.yaml

# drop step-certificates/.../test-connection.yaml because it lacks an image tag
# cf. https://github.com/smallstep/helm-charts/pull/196/files
# rm -v "${OUTPUT_DIR}"/charts/step-certificates/charts/step-certificates/templates/tests/*
