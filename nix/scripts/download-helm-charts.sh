#!/usr/bin/env bash
# This downloads all the required helm chart tarballs.
# All charts published at public.wire.com/charts already do vendor their
# dependencies, so this should be reproducible.
# The location of the downloaded tarball is printed to stdout, to be processed
# further by later steps.
set -eou pipefail

if [[ ! $# -eq 1 ]];then
  echo "usage: $0 OUTPUT-DIR" >&2
  exit 1
fi

# TODO: move this comment elsewhere
# Helm charts can be installed using helm install <release-name> ./<chart>.tgz

HELM_CONFIG_HOME=$(mktemp -d)
export HELM_CONFIG_HOME
HELM_DATA_HOME=$(mktemp -d)
export HELM_DATA_HOME

trap 'rm -Rf -- "$HELM_CONFIG_HOME $HELM_DATA_HOME"' EXIT

out="$1"
mkdir -p "$out"

helm repo add wire https://s3-eu-west-1.amazonaws.com/public.wire.com/charts >&2

charts=(
  # backoffice
  # commented out for now, points to a 2.90.0 container image which doesn't
  # seem to exist on quay.io
  fluent-bit
  kibana
  nginx-ingress-controller
  reaper
  cassandra-external
  databases-ephemeral
  demo-smtp
  elasticsearch-external
  fake-aws
  minio-external
  nginx-ingress-services
  wire-server
  wire-server-metrics
)

# Download all helm charts as tarballs
for chart in "${charts[@]}"; do
  helm pull "wire/$chart" --destination "$out" >&2
done

# Helm pull doesn't show the name of the file it's created, so we need to list
# and echo them later on.
for chart_tarball in "$out"/*; do
  echo "$chart_tarball"
done
