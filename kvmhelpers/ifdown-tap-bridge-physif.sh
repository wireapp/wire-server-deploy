#!/bin/sh
IP="/sbin/ip"
IFCONFIG="/sbin/ifconfig"
SUDO="/usr/bin/sudo"
DHCLIENT="/sbin/dhclient"

. ./tap-bridge-physif-vars.sh

$SUDO $IP link set $1 down promisc off

# remove ourself from the bridge.
$SUDO $BRCTL delif $BRIDGE $1

# this script is not responsible for destroying the tap device.
#ip tuntap del dev $1

BRIDGEDEV=`$SUDO $BRCTL show $BRIDGE | grep tap`

if [ -z "$BRIDGEDEV" ] ; then
    {
	if [ "$SHAREDIF" -eq "0" ] ; then
	    # restore internet on the physical interface.
	    $DHCLIENT -r $BRIDGE
	else
	    # remove the physical device from the bridge.
	    $SUDO $BRCTL delif $BRIDGE $PHYSIF
	    # shut down the physical device.
	    $SUDO $IFCONFIG $PHYSIF down
	fi
	# we are the last one out. burn the bridge.
        $SUDO $IFCONFIG $BRIDGE down
        $SUDO $BRCTL delif $BRIDGE $1
        $SUDO $BRCTL delbr $BRIDGE
	if [ "$SHAREDIF" -eq "0" ] ; then
	    # restore internet on the physical interface.
	    $DHCLIENT -i $PHYSIF
	fi
    }
fi
