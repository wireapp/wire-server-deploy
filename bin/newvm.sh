#!/bin/bash

usage() { echo "Usage: $0 usage:" && grep ") \#" $0 && echo "        <VM name>" ; 1>&2; exit 1; }

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

while getopts ":hm:d:" o; do
    case "${o}" in
	d) # set amount of disk, in gigabytes
	    d=${OPTARG}
	    ;;
	m) # set amount of memory, in gigabytes
	    m=${OPTARG}
	    ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${d}" ] || [ -z "${m}" ]; then
    echo "here"
    usage
fi

echo "disk size = ${d} gigabytes"
echo "memory = ${m} gigabytes"
echo "hostname: " $1

VM_NAME=$1

if [ ! -z $2 ]; then
    echo "ERROR: too many arguments!" 1>&2
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

if [ -d $VM_NAME ]; then
    echo "ERROR: directory for vm $VM_NAME already exists." 1>&2
    echo "no actions performed."
    exit 1
fi
