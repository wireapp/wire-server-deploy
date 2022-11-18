#!/bin/sh
# The bridge shared by all VMs using HOSTBRIDGE. if you change this, you should probably reboot.
export BRIDGE=br0

# The IP of the host system, on the host<->VM network. where we should provide services (dhcp, dns, ...) that the VMs can see.
export BRIDGEIP=172.16.0.1
# The broadcast address for the above network.
export BRIDGEBROADCAST=172.16.0.255

# 0 for true.
# manage ISC DHCPD
export USEDHCP=1
# manage BIND
export USEDNS=1
# manage DNSMASQ
export USEDNSMASQ=0

# Whether to assign an IP and use ufw to provide internet to the VMs using HOSTBRIDGE.
export HOSTROUTE=0

# The paths to binaries we use for bringing up and down the interface.
export BRCTL="/sbin/brctl"
export IP="/sbin/ip"
export IFCONFIG="/sbin/ifconfig"
export SUDO="/usr/bin/sudo"
