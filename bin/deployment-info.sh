#!/usr/bin/env bash
# disallow unset variables and exit if any command fails
set -eu

usage="USAGE: $0 <k8s namespace> <deployment-name (e.g. brig)>"
namespace=${1?$usage}
deployment=${2?$usage}

repo="https://github.com/wireapp/wire-server"

tag=$(kubectl -n "$namespace" get deployment "$deployment" -o json |
    # Filter out only pod image ids
    jq -r '.spec.template.spec.containers[].image' |
    # ignore sidecar containers, etc.
    grep "/wire/$deployment:" |
    # select only docker image tag; not repo
    cut -f2 -d:
)

commit=$(
    # get all tags from repo
    git ls-remote --tags "$repo" |
    grep "image-$tag" |
    cut -f1
)

release=$(helm ls -a |
          grep "wire-server" |
          cut -f5
)

# align output nicely
column -t <(
    echo -e "image-tag\trelease\tcommit\tlink"
    echo -e "$tag\t$release\t$commit\t$repo/releases/tag/image-$tag"
)
