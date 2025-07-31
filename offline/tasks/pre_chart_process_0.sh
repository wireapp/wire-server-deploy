#!/usr/bin/env bash
set -euo pipefail

if [[ ! $# -eq 1 ]]; then
  echo "usage: $0 OUTPUT-DIR" >&2
  exit 1
fi

OUTPUT_DIR="$1"

echo "Running pre-chart process script 0 in dir $OUTPUT_DIR ..."

# Patch wire-server values.yaml to include federator
# This is needed to bundle it's image.
sed -i -Ee 's/federation: false/federation: true/' "${OUTPUT_DIR}"/values/wire-server/prod-values.example.yaml
sed -i -Ee 's/useSharedFederatorSecret: false/useSharedFederatorSecret: true/' "${OUTPUT_DIR}"/charts/wire-server/charts/federator/values.yaml

# drop step-certificates/.../test-connection.yaml because it lacks an image tag
# cf. https://github.com/smallstep/helm-charts/pull/196/files
rm -v "${OUTPUT_DIR}"/charts/step-certificates/charts/step-certificates/templates/tests/*
rm -v "${OUTPUT_DIR}"/charts/smtp/charts/smtp/templates/tests/*
