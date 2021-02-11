#!/usr/bin/env bash
# This consumes a list of helm charts from stdin.
# It will invoke helm template on each of them, passing in values from our
# examples in values/, and obtain the list of container images for each of
# those.
# In cases where no container image tag has been specified, it'll use `latest`.
# The list is sorted and deduplicated, then printed to stdout.
set -eou pipefail

# Some of these images don't contain a "latest" tag. We don't to download /ALL/
# of them, but only :latest in that case - it's bad enough there's no proper
# versioning here.
function optionally_complain() {
  while IFS= read -r image; do
    if [[ $image =~ ":latest" ]]; then
      echo "Container $image with a latest tag found. Fix this chart. not compatible with offline. Components need explicit tags for that" >&2
    elif [[ $image =~ ":" ]]; then
      echo "$image"
    elif [[ $image =~ "@" ]]; then
      echo "$image"
    else
      echo "Container $image without a tag found or pin found. Aborting! Fix this chart. not compatible with offline. Components need explicit tags for that" >&2
      exit 1
    fi
  done
}

# For each helm chart passed in from stdin, use the example values to
# render the charts, and assemble the list of images this would fetch.  This
# isn't perfect, users setting other values in their charts might produce
# different containers, but this is a good approximation for now
while IFS= read -r chart; do
  echo "Running helm template on chart ${chart}…" >&2
  helm template "wire/$chart" \
    -f ./values/$chart/prod-values.example.yaml \
    -f ./values/nginx-ingress-services/prod-values.example.yaml \
    -f ./values/nginx-ingress-services/prod-secrets.example.yaml \
    -f ./values/wire-server/prod-values.example.yaml \
    -f ./values/wire-server/prod-secrets.example.yaml \
    --set allowOrigin=dummy --set host=dummy --set tls.key=dummy --set tls.crt=dummy \
    | yq -r '..|.image? | select(.)' | optionally_complain | sort -u
done | sort -u
