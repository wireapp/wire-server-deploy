#!/usr/bin/env bash

mkdir -p ../admin_work_dir && cd ../admin_work_dir
mkdir -p ../dot_ssh
mkdir -p ../dot_kube

# TODO: if not exists..
#ssh-keygen -N '' -f /root/.ssh/id_rsa
#cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
# copy ssh key
cp ~/.ssh/id_rsa ../dot_ssh/

inside="cp -a /src/* /mnt
# run ansible from here. If you make any changes, they will be written to your host file system
# (those files will be owned by root as docker runs as root)
cd /mnt/wire-server-deploy/ansible
"

# podman
sudo apt-get update -qq
sudo apt-get install -qq -y software-properties-common uidmap
sudo add-apt-repository -y ppa:projectatomic/ppa
sudo apt-get update -qq
sudo apt-get -qq -y install podman

podman run -it --network=host -v $(pwd):/mnt -v $(pwd)/../dot_ssh:/root/.ssh -v $(pwd)/../dot_kube:/root/.kube  quay.io/wire/networkless-admin
