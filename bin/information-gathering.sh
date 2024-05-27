#!/bin/bash

# This script is intended for use by on-premise users of the Wire (wire.com) backend at the request of the Wire support team.
# The script gathers information on the installation and system, and packages that information for easy transmission to the wire Support team, 
# in order to assist with debugging issues.

# Hello.
echo "# Begin Wire information gathering"

# Ensure we are running in sudo mode.
echo "# Ensuring we are in sudo mode"

# Check if the script is running with sudo
if [ "$EUID" -ne 0 ]; then
  # If not, re-run the script with sudo
  sudo "$0" "$@"
  # Exit the original script, or we'll run it twice.
  exit
fi

# Now we are running as sudo.

# Installing the required packages.
sudo apt-get update
sudo apt-get install -y sysbench hardinfo inxi virt-what lshw net-tools ubuntu-report

# Setup
WORK_FOLDER="/tmp/wire-information-gathering/"
FINAL_FILE="/tmp/wire-information-gathering.tar.gz"
URL="https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso"

# Clean work folder if we already ran this
rm -rf $WORK_FOLDER

# Make a folder we will work in
mkdir -p $WORK_FOLDER

# Gather the OS issue
ISSUE=$(cat /etc/issue | tr -d '\\n\\l' | head -n 1)

# Display and save
echo "# 01. Issue is «$ISSUE»"
echo "$ISSUE" > $WORK_FOLDER/01-issue.txt

# Utility to save files to our work folder
save_file(){
    NUMBER=$1
    NAME=$2
    FILE=$3
    echo "# $NUMBER. Saving $NAME"
    echo "# This file contains the contents of the file «$FILE», starting here:" > $WORK_FOLDER/$NUMBER-$NAME.txt 
    cat $FILE >> $WORK_FOLDER/$NUMBER-$NAME.txt 2>/dev/null
}

# Utility to run a command and save it to our work folder
save_command(){
    NUMBER=$1
    NAME=$2
    shift; shift;
    COMMAND=$@
    echo "# $NUMBER. Saving $NAME"
    echo "# This file contains the results of the command «$COMMAND», starting here:" > $WORK_FOLDER/$NUMBER-$NAME.txt 
    $COMMAND >> $WORK_FOLDER/$NUMBER-$NAME.txt 2>&1 
}

# Save log files
save_file 02 dmesg    /var/log/dmesg
save_file 03 kern.log /var/log/kern.log
save_file 04 boot.log /var/log/boot.log
save_file 05 auth.log /var/log/auth.log
save_file 06 dpkg.log /var/log/dpkg.log
save_file 07 faillog  /var/log/faillog
save_file 08 syslog   /var/log/syslog
save_file 09 ufw.log  /var/log/ufw.log

# Save a list of all installed packages
save_command 10 installed-packages apt list --installed

# Save host file
save_file    11 etc-hosts          /etc/hosts

# Save the network hostname
save_command 12 network-hostname   uname -n

# Save the uname kernel info
save_command 13 kernel-info        uname -a

# Save hardware information
save_command 14 hardware-info      lshw

# Save CPU information
save_command 15 cpu-info           lscpu

# Save block devices information
save_command 16 block-devices      lsblk -a

# Save USB controller information
save_command 17 usb-controller     lsusb -v

# Save PCI information
save_command 18 pci-info           lspci -v

# Save partition table
save_command 19 partition          fdisk -l

# Save /proc/ information
save_file 20 proc-cmdline          /proc/cmdline      # Kernel command line information.
save_file 21 proc-console          /proc/console      # Information about current consoles including tty.
save_file 22 proc-devices          /proc/devices      # Device drivers currently configured for the running kernel.
save_file 23 proc-dma              /proc/dma          # Info about current DMA channels.
save_file 24 proc-fb               /proc/fb           # KernelFramebuffer devices.
save_file 25 proc-filesystems      /proc/filesystems  # Current filesystems supported by the kernel.
save_file 26 proc-iomem            /proc/iomem        # Current system memory map for devices.
save_file 27 proc-ioports          /proc/ioports      # Registered port regions for input output communication with device.
save_file 28 proc-loadavg          /proc/loadavg      # System load average.
save_file 29 proc-locks            /proc/locks        # Files currently locked by kernel.
save_file 30 proc-meminfo          /proc/meminfo      # Info about system memory (see above example).
save_file 31 proc-misc             /proc/misc         # Miscellaneous drivers registered for miscellaneous major device.
save_file 32 proc-modules          /proc/modules      # Currently loaded kernel modules.
save_file 33 proc-mounts           /proc/mounts       # List of all mounts in use by system.
save_file 34 proc-partitions       /proc/partitions   # Detailed info about partitions available to the system.
save_file 35 proc-pci              /proc/pci          # Information about every PCI device.
save_file 36 proc-stat             /proc/stat         # Record or various statistics kept from last reboot.
save_file 37 proc-swap             /proc/swap         # Information about swap space.
save_file 38 proc-uptime           /proc/uptime       # Uptime information (in seconds).
save_file 39 proc-version          /proc/version      # Kernel version, gcc version, and Linux distribution installed.

# Save partition table
save_command 40 mount              mount

# Test DNS resolution
save_command 41 dns                ping -c 3 google.com

# Test ping/internet connectivy
save_command 42 ping               ping -c 3 8.8.8.8

# Check disk space usage
save_command 43 disk-usage         df -h

# Check the current language
save_command 44 current-language   set | egrep '^(LANG|LC_)'

# Save network information
save_command 45 network-info       ifconfig -a

# Save IP addresses
save_command 46 ip-addresses       ip addr

# Save network interfaces
save_file    47 network-interfaces /etc/network/interfaces

# Save routing information
save_command 48 routing-info       route -n

# Save all open ports
save_command 49 open-ports         netstat -tulpn

# Save who is logged in
save_command 50 who-is-logged-in   who

# Save list of all running processes
save_command 51 running-processes  ps faux

# Save current user
save_command 52 current-user       id

# Save current date
save_command 53 current-date       date

# Save current UTC date
save_command 54 current-utc-date   date --utc

# Save routing tables
save_command 55 routing-tables     ip route

# Save uptime
save_command 56 uptime             uptime

# Run ubuntu-report and copy the output file
ubuntu-report --non-interactive 2>/dev/null
cp -f ~/.cache/ubuntu-report/* $WORK_FOLDER/57-ubuntu-report.txt

# Save timezone
save_command 58 timezone           timedatectl

# Save locale
save_command 59 locale             locale

# Save APT sources
save_file 60 apt-sources           /etc/apt/sources.list

# Save APT sources.list.d files
save_command 61 apt-files          ls -l /etc/apt/sources.list.d/*

# Save APT sources.list.d contents
save_command 62 apt-contents       cat -n /etc/apt/sources.list.d/*

# Save crontab
save_file 63    crontab            /etc/crontab

# Save Cron files
save_command 64 cron-files         ls -l /etc/cron.d/*

# Save Cron contents
save_command 65 cron-contents      cat -n /etc/cron.d/*

# Save DNSMasq configuration
save_file 66    dnsmasq-conf       /etc/dnsmasq.conf

# CPU Benchmark.
save_command 67 cpu-benchmark      sudo sysbench --test=cpu --cpu-max-prime=20000 run

# File i/o benchmark command 1.
save_command 68 io-benchmark-1     sudo sysbench --test=fileio --file-total-size=2G prepare

# File i/o benchmark command 2.
save_command 69 io-benchmark-2     sudo sysbench --test=fileio --file-total-size=2G --file-test-mode=rndrw run

# File i/o benchmark command 3.
save_command 70 io-benchmark-3     sudo sysbench --test=fileio --file-total-size=2G cleanup

# Memory benchmark.
save_command 71 ram-benchmark      sudo sysbench --test=memory run

# Hardinfo command.
save_command 72 hardinfo           sudo hardinfo

# Inxi basic system information    
save_command 73 inxi-basic         sudo inxi -F

# Inxi full system information 
save_command 74 inxi-full          sudo inxi -Fxz

# Inxi hardware information 
save_command 75 inxi-hardware      sudo inxi -xxx

# Detect if we are running inside a virtual machine.
save_command 76 virt-what          sudo virt-what 

# Download an Ubuntu ISO so we can see the network speed.
save_command 77 internet-speed     wget --progress=bar:force "$URL" -O "/tmp/test-file.iso" 2>&1

# Save the disk space usage (`du`) of the entire disk:
save_command 78 disk-usage         sudo du -hc /

# Log.
echo "# Clean up temporary files"

# Remove the file.
rm -f /tmp/test-file.iso

# Log.
echo "# Compressing into a single file"

# Compress everything into a single file.
tar -czvf $FINAL_FILE $WORK_FOLDER

# Log.
echo "# Your information package has been saved to « $FINAL_FILE », please send it to the Wire support team."
