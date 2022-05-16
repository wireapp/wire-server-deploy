# The bridge shared by all VMs using HOSTBRIDGE. if you change this, you should probably reboot.
BRIDGE=br0

# The IP of the host system, on the host<->VM network. where we should provide services (dhcp, dns, ...) that the VMs can see.
BRIDGEIP=172.16.0.1
# The broadcast address for the above network.
BRIDGEBROADCAST=172.16.0.255

# 0 for true.
# manage ISC DHCPD
USEDHCP=0
# manage BIND
USEDNS=0

# Whether to assign an IP and use ufw to provide internet to the VMs using HOSTBRIDGE.
HOSTROUTE=0

# The paths to binaries we use for bringing up and down the interface.
BRCTL="/sbin/brctl"
IP="/sbin/ip"
IFCONFIG="/sbin/ifconfig"
SUDO="/usr/bin/sudo"

