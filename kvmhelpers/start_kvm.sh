#!/bin/bash
# shellcheck disable=SC2181,SC2001,SC1090,SC2046,SC2154

if [ -n "$AUTOINSTALL" ]; then
    WEBROOT=/home/demo/Wire-Server/autoinstall
    KERNEL_PATH=/mnt/iso/linux
    INITRD_PATH=../initrd
    if [ -f "$KERNEL_PATH" && -f "$INITRD_PATH" ]; then
        NODE=$(basename $(dirname $(readlink -f "$0")))
    else
        echo "Autoinstall requested, but $KERNEL_PATH (linux) or $INITRD_PATH (initrd) missing"
    fi
    PRESEED="d-i/bionic/${NODE}.cfg"
    PRESEED_FILE="${WEBROOT}/${PRESEED}"
    if [ -f "$PRESEED_FILE" ]; then
        $SUDO debconf-set-selections -c "${PRESEED_FILE}"
        PRESEED_MD5=$(md5sum "${PRESEED_FILE}" | cut -c 1-32)
        echo "Autoinstall requested for ${NODE} using preseed file ${PRESEED_FILE}."
        URL="url=http://172.16.0.1/${PRESEED}"
        APPEND_PARAMS="'console=ttyS0 auto=true priority=critical locale=en_US ${URL} preseed-md5=${PRESEED_MD5}'"
        APPEND="-kernel ${KERNEL_PATH} -initrd ${INITRD_PATH} -append ${APPEND_PARAMS}"
        unset DRIVE
        NOREBOOT=-no-reboot
    else
        echo "Autoinstall requested, but preseed file ${PRESEED_FILE} missing. Exiting."
        exit
    fi
else
    unset APPEND
fi
echo $APPEND

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
export eth0=HOSTBRIDGE
export eth1=GUESTBRIDGE

# Set the prefix of the tap interface(s) on the host for this kvm.
# On the host the interface names are:
# "${TAP_PREFIX}_host"      for a HOSTBRIDGE
# "${TAP_PREFIX}_guest"     for a GUESTBRIDGE
# "${TAP_PREFIX}_privport"  for a PRIVATEPORT (not yet supported)
# "${TAP_PREFIX}_shareport" for a SHAREDPORT  (not yet supported)
TAP_PREFIX=tap_node

# Set the decimal value of the last octet of the MAC address for first interface for
# this kvm.  For example if the value is 12 and there are two interfaces for this kvm,
# the MAC addresses will end in '0c' and '0d' respectively.
# WARNING: the MAC addresses cannot overlap with those of another kvm operating at the
# same time!
NEXT_MAC_SEQ=0

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
    source "${config_file}"
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
        unset "$DISPLAY"
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

# set up networking.
for each in ${!eth*}; do
    MACADDR="52:54:00:12:34:$(printf '%02x' $NEXT_MAC_SEQ)"
    if [ "${!each}" == "HOSTBRIDGE" ]; then
        TAPDEV="${TAP_PREFIX}_host"
        NETWORK="$NETWORK -netdev tap,id=$each,ifname=$TAPDEV,script=HOSTBRIDGE.sh,downscript=HOSTBRIDGE-down.sh -device rtl8139,netdev=$each,mac=$MACADDR"
    else
        if [ "${!each}" == "GUESTBRIDGE" ]; then
            TAPDEV="${TAP_PREFIX}_guest"
            NETWORK="$NETWORK -netdev tap,id=$each,ifname=$TAPDEV,script=GUESTBRIDGE.sh,downscript=GUESTBRIDGE-down.sh -device rtl8139,netdev=$each,mac=$MACADDR"
        else
            # SHAREDPORT and PRIVATEPORT not currently supported
            TAPDEV=""
        fi
    fi
    if [ -n "$TAPDEV" ]; then
        echo Setting up tap "$TAPDEV" for device "$each" with mac address "$MACADDR"
        $SUDO $IP tuntap add dev "$TAPDEV" mode tap user "$USER"
    fi
    # keep track of the interfaces created to delete after the kvm closes
    ASSIGNED_TAPS="$ASSIGNED_TAPS $TAPDEV"
    NEXT_MAC_SEQ=$(($NEXT_MAC_SEQ + 1))
done

# boot from the CDROM if the user did not specify to boot from the disk on the command line (DRIVE=c ./start_kvm.sh).
if [ -z "$DRIVE" ]; then
    echo "Booting from CD. run with \"DRIVE=c $0\" in order to boot from the hard disk."
    DRIVE=d
else
    echo "Booting from hard disk."
fi

if [ -z "$NOREBOOT" ]; then
    echo "Booting normally. A reboot will reboot, and keep the VM running."
else
    echo "Booting in single shot mode. a reboot will return you to your shell prompt, powering off the VM."
    NOREBOOT=-no-reboot
fi

sleep 5

# Actually launch qemu-kvm.

# Create the qemu-kvm command
COMMAND="/usr/bin/kvm -m $MEM -boot $DRIVE -drive file=$DISK,index=0,media=disk,format=raw -drive file=$CDROM,index=1,media=cdrom -rtc base=utc $NETWORK $PROCESSORS $CURSES $NOREBOOT ${APPEND}"

# Display the qemu-kvm command
echo "executing:"
echo "$COMMAND"

# Execute the qemu-kvm command
$COMMAND

# VM has shut down, remove all of the taps.
for each in $ASSIGNED_TAPS; do
    {
        $SUDO $IP tuntap del dev "$each" mode tap
    }
done

#### you should not have to modify these. tell the author if you have to. ####
