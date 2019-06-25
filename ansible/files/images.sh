#!/usr/bin/env bash

set -ex

quay=(
wire/brig
wire/galley
)

registry_name="localhost"

prefix=quay.io
for image in ${quay[@]}; do
    docker pull $prefix/$image
    docker tag $prefix/$image $registry_name/$image
    docker push $registry_name/$image
    docker image remove $registry_name/$image
    docker image remove $prefix/$image
done;

