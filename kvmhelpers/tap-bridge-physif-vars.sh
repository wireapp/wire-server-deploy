BRCTL=/sbin/brctl
BRIDGE=br1
MGMT_DIR=/var/local/createvm

# The physical interface we bind to.
PHYSIF=enxf4f951f090bb

# 0 for true.
USEDHCP=1
USEDNS=1
HOSTROUTE=1

# 0 if the interface is shared with the OS, 1 if the OS does not manage the physical interface.
SHAREDIF=1

# only matters if HOSTROUTE is 0.
BRIDGEIP=172.16.0.1
