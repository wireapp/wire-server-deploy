#!/usr/bin/env bash

set -eou pipefail

# This downloads all the required helm chart tarballs needed for an offline deploy,
# extracts the referenced container images, and prints them to stdout


# TODO: move this comment elsewhere
# Helm charts can be installed using helm install <release-name> ./<chart>.tgz
# Images can be imported using skopeo sync, see the corresponding
# import-offline-package.sh script.

export HELM_CONFIG_HOME=$(mktemp -d)
export HELM_DATA_HOME=$(mktemp -d)
out=$(mktemp -d)
mkdir -p "$out/charts"

trap 'rm -f -- "$out $HELM_CONFIG_HOME $HELM_DATA_HOME"' EXIT

helm repo add wire https://s3-eu-west-1.amazonaws.com/public.wire.com/charts >&2

charts=(
  # backoffice # commented out for now, points to 2.90.0 which doesn't seem to exist on quay.io
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
# TODO: why do we download here? should this go to another output?
for chart in "${charts[@]}"; do
  echo "Downloading helm chart ${chart}…" >&2
  helm pull "wire/$chart" --destination "$out/charts" >&2
done

# For each helm chart, use the example values to render the charts,
# and assemble the list of images this would fetch.
# This isn't perfect, users setting other values in their charts ight produce
# different containers, but this is a good approximation for now
for chart in "$out/charts/"*.tgz; do
  >&2 echo "Running helm template on chart ${chart}…"
  helm template "$chart" \
    -f ./values/fake-aws/prod-values.example.yaml \
    -f ./values/nginx-ingress-services/prod-values.example.yaml \
    -f ./values/nginx-ingress-services/prod-secrets.example.yaml \
    -f ./values/wire-server/prod-values.example.yaml \
    -f ./values/wire-server/prod-secrets.example.yaml
done  | yq -r '..|.image? | select(.)' | sort -u | uniq > "${out}/docker-images_helm_template.txt"

# Some of these images don't contain a "latest" tag. We don't to download /ALL/
# of them, but only :latest in that case - it's bad enough there's no proper
# versioning here.

images_without_tag=$(grep -v ':' "${out}/docker-images_helm_template.txt")

# copy those with versions to docker-images.txt
grep ':' "${out}/docker-images_helm_template.txt" > "${out}/docker-images.txt"
for image_without_tag in $images_without_tag;do
  echo "$image_without_tag:latest" >> "${out}/docker-images.txt"
done

# output sorted list
sort < ${out}/docker-images.txt
