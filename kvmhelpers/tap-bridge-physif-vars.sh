#!/bin/bash
export BRCTL=/sbin/brctl
export BRIDGE=br1
export MGMT_DIR=/var/local/createvm

# The physical interface we bind to.
export PHYSIF=enxf4f951f090bb

# 0 for true.
export USEDHCP=1
export USEDNS=1
export HOSTROUTE=1

# 0 if the interface is shared with the OS, 1 if the OS does not manage the physical interface.
export SHAREDIF=1

# only matters if HOSTROUTE is 0.
export BRIDGEIP=172.16.0.1
