#!/bin/sh

IP="/sbin/ip"
IFCONFIG="/sbin/ifconfig"
SUDO="/usr/bin/sudo"
DHCLIENT="/sbin/dhclient"

{

. ./tap-bridge-physif-vars.sh

BRIDGEDEV=`$BRCTL show|grep -E ^"$BRIDGE"`

if [ -n "$BRIDGEDEV" ] ; then
    {
        $SUDO $BRCTL addif $BRIDGE $1
	$SUDO $IP link set $1 up promisc on
    }
else
    {
        $SUDO $BRCTL addbr $BRIDGE
	if [ "$HOSTROUTE" -eq "0" ] ; then
	    $SUDO $IP addr add $BRIDGEIP/24 broadcast $BRIDGEBROADCAST dev $BRIDGE
	fi
        $SUDO $BRCTL stp $BRIDGE off
	$SUDO $IP link set $1 up promisc on
        $SUDO $BRCTL addif $BRIDGE $1
        $SUDO $BRCTL addif $BRIDGE $PHYSIF
	if [ "$SHAREDIF" -eq "0" ] ; then
	    # FIXME: assumes DHCP, assumes all kind of things.
	    $SUDO $DHCLIENT -r $PHYSIF
	    $SUDO $DHCLIENT -i $BRIDGE
	fi
        $SUDO $IP link set $PHYSIF up
        $SUDO $IP link set $BRIDGE up
        if [ "$USEDHCP" -eq "0" ] ; then 
            $SUDO service isc-dhcp-server stop
            $SUDO service isc-dhcp-server start
	    # workaround arno and fail2ban not working well together.
#            $SUDO service fail2ban stop
#            $SUDO service fail2ban start
        fi
        if [ "$USEDNS" -eq "0" ]; then
            $SUDO service bind9 restart
        fi
    }
fi

if [ "$HOSTROUTE" -eq "0" ]; then
    # Allow VMs to use ip masquerading on the host to contact the internet, as well as to have port forwards.
    $SUDO service ufw restart
fi

echo "Bridge ifup completed."
} 2>&1 > tapbridgephysif.ifup
