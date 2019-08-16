#!/usr/bin/env bash

set -ex

BACKEND_VERSION=2.59.0

images=( brig galley gundeck cannon proxy spar cargohold nginz )
for image in "${images[@]}"; do
    docker pull "quay.io/wire/$image:$BACKEND_VERSION"
    docker save "quay.io/wire/$image:$BACKEND_VERSION" > "$image-$BACKEND_VERSION.tar"
done


