#!/usr/bin/env bash

set -ex

for image in *.tar; do
    docker load < "$image"
done

# TODO: be smarter about docker images and discover names and versions from docker load
BACKEND_VERSION=2.59.0
PREFIX=wire
REGISTRY=quay.io

images=( brig galley gundeck cannon proxy spar cargohold nginz )
for image in "${images[@]}"; do
    img="$PREFIX/$image:$BACKEND_VERSION"
    docker tag "$REGISTRY/$img" "localhost/$img"
    docker push "localhost/$img"
done

# TODO: be sure to have loaded and pushed everything before deleting
#echo "you may remove the tar files with: rm *.tar"

