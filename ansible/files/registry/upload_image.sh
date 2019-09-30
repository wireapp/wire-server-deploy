#!/usr/bin/env bash

registry_name="localhost:5001"

function mirror() {
    prefix=$1
    image=$2
    rmafter=$3
    docker pull $prefix/$image
    docker tag $prefix/$image $registry_name/$image
    docker push $registry_name/$image
    [ -n "$rmafter" ] && docker image remove $registry_name/$image
    [ -n "$rmafter" ] && docker image remove $prefix/$image
}

mirror $1 $2 yes
