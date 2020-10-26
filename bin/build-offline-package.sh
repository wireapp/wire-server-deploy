#!/usr/bin/env bash

set -eou pipefail

# This downloads all the required helm chart tarballs needed for an offline deploy,
# extracts the referenced container images, and downloads them as well.
# Helm charts can be installed using helm install <release-name> ./<chart>.tgz
# Images can be imported using skopeo sync, see the corresponding
# import-offline-package.sh script.

if [[ $# != 1 ]]; then
  >&2 echo "Please specify the output dir as first argument!"
  exit 2
fi

out=$1
if [[ -e "$out" ]]; then
  >&2 echo "$out already exists, bailing out!"
  exit 2
fi


helm repo add wire https://s3-eu-west-1.amazonaws.com/public.wire.com/charts

mkdir -p "$out/charts"

charts=(
  backoffice
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
  echo "Downloading helm chart ${chart}…"
  helm pull "wire/$chart" --destination "$out/charts"
done

# For each helm chart; download all images
for chart in "$out/charts/"*.tgz; do
  >&2 echo "Running helm template on chart ${chart}…"
  helm template "$chart" \
    -f ./values/fake-aws/prod-values.example.yaml \
    -f ./values/nginx-ingress-services/prod-values.example.yaml \
    -f ./values/nginx-ingress-services/prod-secrets.example.yaml \
    -f ./values/wire-server/prod-values.example.yaml \
    -f ./values/wire-server/prod-secrets.example.yaml \
    -f ./values/wire-server/secrets.yaml
done  | yq -r '..|.image? | select(.)' | sort -u > "${out}/docker-images.txt"

# Some of these images don't contain a "latest" tag. We don't to download /ALL/
# of them, but only :latest in that case - it's bad enough there's no proper
# versioning here.
sed -i 's//' "${out}/docker-images.txt"


# Download all the docker images
for image in $(cat $out/docker-images.txt); do
    echo "Downloading container image ${image}…"
    skopeo sync --src docker --dest dir --scoped $image $out/registry/
done
