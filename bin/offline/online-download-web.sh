#!/usr/bin/env bash

set -ex

function download() {
    local NAME=$1
    local VERSION=$2
    docker pull "quay.io/wire/$NAME:$VERSION"
    docker save "quay.io/wire/$NAME:$VERSION" > "$NAME-$VERSION.tar"
}

download webapp "42720-0.1.0-64e6cb-v0.22.0-production"


# requires authentication!
download team-settings "10562-2.8.0-9e1e59-v0.22.1-production"
