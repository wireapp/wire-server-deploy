#!/usr/bin/env bash

set -ex

# When this script is run the first time, copy files over
if [[ ! -d /mnt/wire-server-deploy ]]; then
   cp -a /src/* /mnt
fi

# run ansible from here. If you make any changes, they will be written to your host file system
# (those files will be owned by root as docker runs as root)
cd /mnt/wire-server-deploy/ansible

# This code may be brittle...
TARGET_IFACE=$(route | grep default | awk '{print $8}')
TARGET_HOST=$(/sbin/ifconfig $TARGET_IFACE | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')

if [[ ! -f hosts.ini ]]; then
   curl -sSfL https://raw.githubusercontent.com/wireapp/wire-server-deploy/feature/simple-bootstrap/ansible/hosts.example-demo.ini > hosts.example-demo.ini
   cp hosts.example-demo.ini hosts.ini
   sed -i "s/X.X.X.X/$TARGET_HOST/g" hosts.ini
fi


