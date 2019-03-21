#!/usr/bin/env bash
# disallow unset variables and exit if any command fails
set -eu

usage="USAGE: $0 <k8s namespace> <deployment-name (e.g. brig)>"
namespace=${1?$usage}
deployment=${2?$usage}

wire_server_repo="https://github.com/wireapp/wire-server"
wire_server_deploy_repo="https://github.com/wireapp/wire-server-deploy"

resource_type=deployment
if [[ "$2" == cannon ]]; then
    resource_type=statefulsets
fi

image=$(
    kubectl -n "$namespace" get "$resource_type" "$deployment" -o json |
    # Filter out only pod image ids
    jq -r '.spec.template.spec.containers[].image' |
    # ignore sidecar containers, etc.
    grep "/wire/$deployment:"
)

# select only docker image tag; not repo
image_tag="image/$(echo "$image" | cut -f2 -d:)"

wire_server_commit=$(
    # get all tags from repo
    git ls-remote --tags "$wire_server_repo" |
    grep "$image_tag" |
    cut -f1 |
    tr -d ' \t\n'
)

chart_version=$(
    helm ls -a |
    grep "wire-server" |
    cut -f5 |
    tr -d ' \t\n'
)

wire_server_deploy_commit=$(
    git ls-remote --tags "$wire_server_deploy_repo" |
    grep "$chart_version" |
    cut -f1 |
    tr -d ' \t\n'
)

# align output nicely
column -t <(
    echo -e "docker_image:\t$image"
    echo -e "chart_version:\t$chart_version"
    echo -e "wire_server_commit:\t$wire_server_commit"
    echo -e "wire_server_link:\t$wire_server_repo/releases/tag/$image_tag"
    echo -e "wire_server_deploy_commit:\t$wire_server_deploy_commit"
    echo -e "wire_server_deploy_link:\t$wire_server_deploy_repo/releases/tag/chart/$chart_version"
 )
