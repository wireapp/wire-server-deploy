#!/usr/bin/env bash

set -eo pipefail

nocloud_basedir=/home/demo/wire-server-deploy/nocloud

prepare_config() {
    # Run
    # export OFFLINE_PASSWORD="$(mkpasswd)"
    # to set the hashed password
    set -u
    # shellcheck disable=SC2153
    offline_username=$OFFLINE_USERNAME
    # shellcheck disable=SC2153
    offline_password=$OFFLINE_PASSWORD
    set +u

    name="$1"
    d=$nocloud_basedir/$name
    mkdir -p "$d"
    touch "$d"/vendor-data
    touch "$d"/meta-data
    cat >"$d/user-data"<<EOF
#cloud-config
autoinstall:
  version: 1
  id: ubuntu-server-minimized
  network:
    version: 2
    ethernets:
      enp1s0:
        dhcp4: yes
  identity:
    hostname: $name
    password: $offline_password
    username: $offline_username
  ssh:
    install-server: yes
EOF
}

create_assethost () {
    name="$1"

    prepare_config "$name"

    # if you want to run the installation manually remove the `--noautoconsole` flag and the ds= part from `--extra-args`
    sudo virt-install \
       --name "$name" \
        --ram 8192 \
       --disk path=/var/kvm/images/"$name".img,size=100  \
       --vcpus 4 \
       --network bridge=br0 \
       --graphics none \
       --osinfo detect=on,require=off \
       --noautoconsole \
       --location /home/demo/wire-server-deploy/ubuntu.iso,kernel=casper/vmlinuz,initrd=casper/initrd \
       --extra-args "console=ttyS0,115200n8 autoinstall ds=nocloud-net;s=http://172.16.0.1:3003/$name"
}

create_node () {
    name="$1"

    prepare_config "$name"

    # if you want to run the installation manually remove the `--noautoconsole` flag and the ds= part from `--extra-args`
    sudo virt-install \
        --name "$name" \
        --ram 8192 \
        --disk path=/var/kvm/images/"$name".img,size=80 \
        --vcpus 6 \
        --network bridge=br0 \
        --graphics none \
        --osinfo detect=on,require=off \
        --noautoconsole \
        --location /home/demo/wire-server-deploy/ubuntu.iso,kernel=casper/vmlinuz,initrd=casper/initrd \
        --extra-args "console=ttyS0,115200n8 autoinstall ds=nocloud-net;s=http://172.16.0.1:3003/$name"
}

if [ "$1" = "serve_nocloud" ]; then
    mkdir -p "$nocloud_basedir"
    cd "$nocloud_basedir"
    python3 -m http.server 3003
fi

if [ "$1" = "create_node" ]; then
    set -u
    name="$2"
    create_node "$name"
fi

if [ "$1" = "create_assethost" ]; then
    set -u
    name="$2"
    create_assethost "$name"
fi
