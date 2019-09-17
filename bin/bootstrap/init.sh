#!/usr/bin/env bash

mkdir -p ../admin_work_dir && cd ../admin_work_dir
mkdir -p ../dot_ssh
mkdir -p ../dot_kube

if [[ ! -f /root/.ssh/id_rsa ]]; then
    # create ssh key and allow self to ssh in (from a docker image)
    ssh-keygen -N '' -f /root/.ssh/id_rsa
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
fi

# copy ssh key
cp ~/.ssh/id_rsa ../dot_ssh/

# podman
sudo apt-get update -qq
sudo apt-get install -qq -y software-properties-common uidmap
sudo add-apt-repository -y ppa:projectatomic/ppa
sudo apt-get update -qq
sudo apt-get -qq -y install podman

curl -sSfL https://raw.githubusercontent.com/wireapp/wire-server-deploy/feature/simple-bootstrap/bin/bootstrap/inside.sh > inside.sh
chmod +x inside.sh

podman run -it --network=host -v $(pwd):/mnt -v $(pwd)/../dot_ssh:/root/.ssh -v $(pwd)/../dot_kube:/root/.kube  quay.io/wire/networkless-admin
