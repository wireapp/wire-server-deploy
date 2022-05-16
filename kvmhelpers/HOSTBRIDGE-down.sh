#!/bin/sh

. ./HOSTBRIDGE-vars.sh

$SUDO $IP link set $1 down promisc off
#$SUDO $IFCONFIG $1 0.0.0.0 promisc down

# remove ourself from the bridge.
$SUDO $BRCTL delif $BRIDGE $1

# this script is not responsible for destroying the tap device.
#ip tuntap del dev $1

BRIDGEDEV=`$SUDO $BRCTL show|grep -E ^"$BRIDGE" | grep tap`

if [ -z "$BRIDGEDEV" ] ; then
    {
	# we are the last one out. burn the bridge.
        $SUDO $IFCONFIG $BRIDGE down
        $SUDO $BRCTL delif $BRIDGE $1
        $SUDO $BRCTL delbr $BRIDGE
    }
fi
