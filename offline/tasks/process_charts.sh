#!/usr/bin/env bash
set -euo pipefail

echo "Processing Helm charts..."

# Default exclude list
IMAGE_EXCLUDE_LIST=""

for arg in "$@"
do
  case $arg in
    IMAGE_EXCLUDE_LIST=*)
      IMAGE_EXCLUDE_LIST="${arg#*=}"
      ;;
  esac
done

# Check if IMAGE_EXCLUDE_LIST is set, otherwise use a default pattern that matches nothing
EXCLUDE_PATTERN=${IMAGE_EXCLUDE_LIST:-".^"}

echo "Excluding images matching the pattern: $EXCLUDE_PATTERN"

# Get and dump required containers from Helm charts. Omit integration test
# containers (e.g. `quay.io_wire_galley-integration_4.22.0`.)
for chartPath in "$(pwd)"/charts/*; do
  echo "$chartPath"
done | list-helm-containers | grep -v "\-integration:" > images 

# images from patch-ingress-controller-images
echo "registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20220916-gd32f8c343" >> images
echo "registry.k8s.io/ingress-nginx/controller:v1.6.4" >> images

grep -vE "$EXCLUDE_PATTERN" images | create-container-dump containers-helm

tar cf containers-helm.tar containers-helm
[[ "$INCREMENTAL" -eq 0 ]] && rm -r containers-helm
