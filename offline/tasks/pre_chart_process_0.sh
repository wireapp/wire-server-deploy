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
rm -v "${OUTPUT_DIR}"/charts/step-certificates/charts/step-certificates/templates/tests/*

# Replace the ingress-nginx subchart of ingress-nginx-controller (WPB-26631).
# The ingress-nginx-controller chart from wire-builds bundles ingress-nginx
# 4.11.5, whose controller images have known CVEs. 4.13.9 is the latest
# release that supports the Kubernetes version installed by this bundle
# (kube_version v1.29.10, see ansible/inventory/offline/group_vars/all/offline.yml).
# Controller >= 1.12 needs `annotations-risk-level: Critical`, see
# values/ingress-nginx-controller/*.example.yaml.
INGRESS_NGINX_CHART_VERSION="4.13.9"
ingress_controller_chart="${OUTPUT_DIR}/charts/ingress-nginx-controller"
if [[ -d "$ingress_controller_chart" ]]; then
  rm -rf "$ingress_controller_chart/charts/ingress-nginx"
  helm pull ingress-nginx \
    --repo https://kubernetes.github.io/ingress-nginx \
    --version "$INGRESS_NGINX_CHART_VERSION" \
    --untar --untardir "$ingress_controller_chart/charts"
  # only the indented dependency version, not the chart's own version
  sed -i -Ee "s/^(  version: )[0-9.]+$/\1${INGRESS_NGINX_CHART_VERSION}/" "$ingress_controller_chart/Chart.yaml"
  rm -f "$ingress_controller_chart/Chart.lock"
fi
