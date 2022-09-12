#!/bin/bash

usage() { echo "Usage: $0 usage:" && grep ") \#" "$0" && echo "        <VM name>" 1>&2; exit 1; }

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

while getopts ":qm:d:c:" o; do
    case "${o}" in
	d) # set amount of disk, in gigabytes
	    d=${OPTARG}
	    ;;
	m) # set amount of memory, in megabytes
	    m=${OPTARG}
	    ;;
	c) # set amount of CPU cores.
	    c=${OPTARG}
	    ;;
	q) # use qemu instead of kvm.
	    q=1
    *) # un-handled cases
        usage 
        ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${d}" ] || [ -z "${m}" ]; then
    echo "here"
    usage
fi

VM_NAME=$1

if [ -n "$2" ]; then
    echo "ERROR: too many arguments!" 1>&2
    usage
fi

if [ -z "$VM_NAME" ]; then
    echo "ERROR: no VM name specified?" 1>&2
    usage
fi

if [ ! -f ubuntu.iso ]; then
    echo "ERROR: no ubuntu.iso found in $SCRIPT_DIR" 1>&2
    echo "no actions performed."
    exit 1
fi

if [ ! -d "./kvmhelpers" ]; then
    echo "ERROR: could not find kvmhelpers directory." 1>&2
    echo "no actions performed."
    exit 1
fi

if [ -d "$VM_NAME" ]; then
    echo "ERROR: directory for vm $VM_NAME already exists." 1>&2
    echo "no actions performed."
    exit 1
fi

echo "disk size = ${d} gigabytes"
echo "memory = ${m} megabytes"
echo "CPUs: ${c}"
echo "hostname: $VM_NAME"
if [ ! -z "$q" ]; then
    echo "USE QEMU"
fi

# exit 0

mkdir "$VM_NAME"
cp ./kvmhelpers/* "$VM_NAME"/
qemu-img create "$VM_NAME"/drive-c.img ${d}G
sed -i "s/MEM=.*/MEM=${m}/" "$VM_NAME"/start_kvm.sh
sed -i "s@CDROM=.*@CDROM=../ubuntu.iso@" "$VM_NAME"/start_kvm.sh
sed -i "s/^eth1=/#eth1=/" "$VM_NAME"/start_kvm.sh
sed -i "s/^CPUS=.*/CPUS=${c}/" "$VM_NAME"/start_kvm.sh
sed -i 's/\(.*\)CURSES=.*/\1CURSES="-nographic -device sga"/' "$VM_NAME"/start_kvm.sh

if [ ! -z "$q" ]; then
    echo "forcing QEMU."
    sed -i "s=/usr/bin/kvm=/usr/bin/qemu-system-x86_64=" "$VM_NAME"/start_kvm.sh
fi
