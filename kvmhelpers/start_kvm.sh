#!/bin/bash

# How much memory to allocate to this VM.
MEM=2048

# How many CPUs to allocate to this VM. note: you can allocate a total of more than you have, this is fine.
CPUS=2

# The CDROM image. Used for installing.
CDROM=../ubuntu-18.04.3-live-server-amd64.iso

# The disk image.
DISK=drive-c.img

# How to wire up the network cards. To add more ports, just add more eth<n> entries.
#  HOSTBRIDGE talks to the physical machine.
#  GUESTBRIDGE talks only to other VMs.
#  PRIVATEPORT talks to other VMs and a physical port on the host.
#  SHAREDPORT talks to other VMs and a physical port on the host, which also uses that port for internet access.
eth0=HOSTBRIDGE
eth1=GUESTBRIDGE

# Where the global configuration is at. stores global settings, like whether to use graphics or text.
#config_file="start_kvm-vars.sh"

# Uncomment if you want to always use the ncurses frontend, EG, you are trying to run this without a GUI.
# Note that this script will detect the presence of GUI access, so enabling this will disable that.
#CURSES="-curses"


# You should not have to modify anything below this line.
#=====================================LINE================================

# Load an optional configuration file.
if [ -n "${config_file+x}" ]; then
    echo "loading config file: ${config_file}"
    source ${config_file}
fi

# Create parameters from the CPUS setting above
if [ -n "${CPUS+x}" ]; then
    echo "Restricting to $CPUS processors."
    PROCESSORS="-smp cores=$CPUS"
fi

# select an interface.
if [ -z "${DISPLAY+x}" ]; then
    CURSES="-curses"
else
    if [ -n "${CURSES+x}" ]; then
        echo "Disabling graphical display."
        unset $DISPLAY
    fi
fi


# paths to binaries we use.
IP="/sbin/ip"
SUDO="/usr/bin/sudo"
WHOAMI="/usr/bin/whoami"
GREP="/bin/grep"
WC="/usr/bin/wc"
SEQ="/usr/bin/seq"
SORT="/usr/bin/sort"
TAIL="/usr/bin/tail"
SED="/bin/sed"

# The user who is running this script.
USER=$(${WHOAMI})

# Claim a tap device, and use it.
function claim_tap() {

    TAPDEVS=$($IP tuntap | $GREP -E ^tap | $SED "s/:.*//")
    TAPDEVCOUNT=$(echo -n "$TAPDEVS" | $WC -l)
    # First, try to fill in any gaps.
    LASTTAP=$(echo -n "$TAPDEVS" | $SED "s/t..//" | $SORT -g | $TAIL -n 1)
    for each in $($SEQ 0 $LASTTAP); do
        if [ $(($TAPSTRIED + $TAPDEVCOUNT)) == $LASTTAP ]; then
            break
        fi
        if [ -z "$($IP tuntap | $GREP -E ^tap$each)" ]; then
            $SUDO $IP tuntap add dev tap$each mode tap user $USER
            if [ $? -eq 0 ]; then
                echo tap$each
                return 0
            fi
            TAPSTRIED=$(($TAPSTRIED+1))
        fi
    done

    # Then, try to claim one on the end. up to 99
    for each in $($SEQ $(($LASTTAP+1)) 99); do
        $SUDO $IP tuntap add dev tap$each mode tap user $USER
        if [ $? -eq 0 ]; then
            echo tap$each
            return 0
        fi
    done
}

# set up networking.
for each in ${!eth*}; do
    TAPDEV=$(claim_tap)
    ASSIGNED_TAPS="$ASSIGNED_TAPS $TAPDEV"
    MACADDR="52:54:00:12:34:$(printf '%02g' `echo $TAPDEV | sed 's/tap//'`)"
    echo Setting up tap $TAPDEV for device $each with mac address $MACADDR
    if [ "${!each}" == "HOSTBRIDGE" ]; then
        NETWORK="$NETWORK -netdev tap,id=$each,ifname=$TAPDEV,script=HOSTBRIDGE.sh,downscript=HOSTBRIDGE-down.sh -device rtl8139,netdev=$each,mac=$MACADDR"
    else if [ "${!each}" == "GUESTBRIDGE" ]; then
             NETWORK="$NETWORK -netdev tap,id=$each,ifname=$TAPDEV,script=GUESTBRIDGE.sh,downscript=GUESTBRIDGE-down.sh -device rtl8139,netdev=$each,mac=$MACADDR"
         fi
    fi
done

# boot from the CDROM if the user did not specify to boot from the disk on the command line (DRIVE=c ./start_kvm.sh).
if [ -z "$DRIVE" ] ; then
    echo "Booting from CD. run with \"DRIVE=c $0\" in order to boot from the hard disk."
    DRIVE=d
else
    echo "Booting from hard disk."
fi

# Actually launch qemu-kvm.
/usr/bin/kvm -m $MEM -boot $DRIVE -drive file=$DISK,index=0,media=disk,format=raw -drive file=$CDROM,index=1,media=cdrom -rtc base=localtime $NETWORK $PROCESSORS $CURSES

# VM has shut down, remove all of the taps.
for each in $ASSIGNED_TAPS; do
    {
        $SUDO ip tuntap del dev $each mode tap
    }
done

#### you should not have to modify these. tell the author if you have to. ####
