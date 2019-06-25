#!/usr/bin/env bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

registry_name="localhost"

images=$(cat $SCRIPT_DIR/list_of_docker_images.txt)
quay=$(cat $SCRIPT_DIR/list_of_docker_images.txt | grep "^quay.io" | awk -F quay.io/ '{print $2}' | grep -v '^$' )
gcr=$(cat $SCRIPT_DIR/list_of_docker_images.txt | grep "^gcr.io" | awk -F gcr.io/ '{print $2}' | grep -v '^$')
k8sgcr=$(cat $SCRIPT_DIR/list_of_docker_images.txt | grep "^k8s.gcr.io" | awk -F k8s.gcr.io/ '{print $2}' | grep -v '^$')
hub=$(cat $SCRIPT_DIR/list_of_docker_images.txt | grep -v gcr.io | grep -v quay.io)


function mirror() {
    docker pull $prefix$image
    docker tag $prefix$image $registry_name/$image
    docker push $registry_name/$image
    #docker image remove $registry_name/$image
    #docker image remove $prefix/$image
}

prefix=quay.io/
for image in ${quay[@]}; do
    mirror
done;

prefix=k8s.gcr.io/
for image in ${k8sgcr[@]}; do
    mirror
done;

prefix=gcr.io/
for image in ${gcr[@]}; do
    mirror
done;

prefix=""
for image in ${hub[@]}; do
    mirror
done;

