#!/usr/bin/env bash

# When this script is run the first time, copy files over
if [[ ! -d /mnt/wire-server-deploy ]]; then
   cp -v -a /src/* /mnt
fi

# run ansible from here. If you make any changes, they will be written to your host file system
# (those files will be owned by root as docker runs as root)
cd /mnt/wire-server-deploy/ansible


# This code may be brittle...
TARGET_IFACE=$(route | grep default | awk '{print $8}')
TARGET_HOST=$(/sbin/ifconfig $TARGET_IFACE | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')

if [[ ! -f hosts.ini ]]; then
   cp hosts.example.ini hosts.ini
   sed -i "s/X.X.X.X/$TARGET_HOST/g" hosts.ini
   sed -i "s/# docker_dns_servers_strict = false/docker_dns_servers_strict = false/g" hosts.ini
   sed -i "s/#docker_dns_servers_strict = false/docker_dns_servers_strict = false/g" hosts.ini
fi
