#!/usr/bin/env bash
set -euo pipefail

if [[ ! $# -eq 1 ]]; then
  echo "usage: $0 OUTPUT-DIR" >&2
  exit 1
fi

OUTPUT_DIR="$1"

echo "Running post-chart process script 0 in dir ${OUTPUT_DIR} ..."

# Undo changes on wire-server values.yaml
sed -i -Ee 's/useSharedFederatorSecret: true/useSharedFederatorSecret: false/' "${OUTPUT_DIR}"/charts/wire-server/charts/federator/values.yaml
sed -i -Ee 's/federation: true/federation: false/' "${OUTPUT_DIR}"/values/wire-server/prod-values.example.yaml
