# Scope

This document gives exact instructions for performing an offline installation of Wire on a single VM from Hetzner. it uses the KVM virtual machine system to create all of the required virtual machines.

This document also gives instructions for creating a TURN calling server on a separate VM.

## Use the hetzner robot console to create a new server.

Select Ubuntu 18.04 or Ubuntu 20.04 on an ax101 dedicated server.

If not using Hetzner, for reference, the specs of the ax101 server are:

* AMD Ryzen™ 9 5950X
* 128 GB DDR4 ECC RAM
* 2 x 3.84 TB NVMe SSD Datacenter Edition (software RAID 1) 
* 1 GBit/s port

In our example, the returned IP when creating the server was: 65.21.197.76

## Pre-requisites

First off, generate a ssh key if you do not have one already.

```
ssh-keygen -t ed25519
```

## tighten security.

### log in as root.

```
ssh -i ~/.ssh/id_ed25519 root@65.21.197.76 -o serveraliveinterval=60
```

### update OS
When prompted about the ssh config, just accept the maintainer's version.
```
apt update
apt upgrade -y
```

### Install tmate

Tmate is a terminal sharing service, which you might need in order for more than one person to collaborate on solving issues, Wire might ask you for a tmate session when debugging any problem you encounter.

```
sudo apt install tmate
```

If asked, to start a tmate session, you would simply then do:

```
tmate
```

And copy/paste the links that are generated, which would then result in the terminal session being shared with whomever you shared the links with.

### Reboot
reboot to load a new, patched kernel.
```
reboot
```

### Disable password login for sshd

Make sure the following values are configured in /etc/ssh/sshd_config:
```
# this is the important value
PasswordAuthentication no

# make sure PAM and Challenge Response is also disabled
ChallengeResponseAuthentication no
UsePAM no

# don't allow root to login via password
PermitRootLogin prohibit-password
```
### re-start SSH
```
service ssh restart
```

### Install fail2ban
```
apt install fail2ban
```

## Create demo user.

### create our 'demo' user
```
adduser --disabled-password --gecos "" demo
```

### copy ssh key to demo user

```
mkdir ~demo/.ssh
cp ~/.ssh/authorized_keys /home/demo/.ssh/
chown demo.demo ~demo/.ssh/
chown demo.demo ~demo/.ssh/authorized_keys
```

### add a configuration for demo not to need a password in order to SUDO.

```
echo "demo ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/10-demo_user
chmod 440 /etc/sudoers.d/10-demo_user
```

## ssh in as demo user.

on the remote machine:
```
logout
```

on the local machine:
```
ssh -i ~/.ssh/id_ed25519 demo@65.21.197.76 -o serveraliveinterval=60
```

## disable root login via ssh

use sudo to edit /etc/ssh/sshd_config, and set the following:
```
# even better: don't allow to login as root via ssh at all
PermitRootLogin no
```

### re-start SSH
```
sudo service ssh restart
```

### Install screen
```
sudo apt install screen
```

### Start a screen session
```
screen
```

### download offline artifact.
```
wget https://s3-eu-west-1.amazonaws.com/public.wire.com/artifacts/wire-server-deploy-static-03fad4ff6d9a67eb56668fb259a0c1571cabcac4.tgz
```

### extract offline artifact.

```
mkdir Wire-Server
cd Wire-Server
tar -xzf ../wire-server-deploy-static-*.tgz
```

### extract debian archive
We'll use the docker that is in the archive.

```
tar -xf debs.tar
```

### (FIXME: add iptables to the repo) Install Docker from debian archive.
```
sudo apt -y install iptables
sudo dpkg -i debs/public/pool/main/d/docker-ce/docker-ce-cli_*.deb
sudo dpkg -i debs/public/pool/main/c/containerd.io/containerd.io_*.deb 
sudo dpkg -i debs/public/pool/main/d/docker-ce/docker-ce_*.deb
sudo dpkg --configure -a
```

### (missing) point host OS to debian archive

### (rewrite) Install networking tools
We're going to install dnsmasq in order to provide DNS to virtual machines, and DHCP to virtual machines. networking will be handled by ufw.

Note that dnsmasq always fails when it installs. the failures (red stuff) is normal.
```
sudo systemctl disable systemd-resolved
sudo apt install dnsmasq ufw -y
sudo systemctl stop systemd-resolved
```

### Tell dnsmasq to provide DNS locally.
```
sudo bash -c 'echo "listen-address=127.0.0.53" > /etc/dnsmasq.d/00-lo-systemd-resolvconf'
sudo bash -c 'echo "no-resolv" >> /etc/dnsmasq.d/00-lo-systemd-resolvconf'
sudo bash -c 'echo "server=8.8.8.8" >> /etc/dnsmasq.d/00-lo-systemd-resolvconf'
sudo service dnsmasq restart
```

### Configure Firewall
```
sudo ufw allow 22/tcp
sudo ufw allow from 172.16.0.0/24 proto udp to any port 53
sudo ufw allow from 127.0.0.0/24 proto udp to any port 53
sudo ufw allow in on br0 from any proto udp to any port 67
sudo ufw enable
```

### (temporary) copy helper scripts from wire-server-deploy
```
sudo apt install git -y
git clone https://github.com/wireapp/wire-server-deploy.git
cp -a wire-server-deploy/kvmhelpers/ ./
cp -a wire-server-deploy/bin/newvm.sh ./bin
cp -a wire-server-deploy/ansible/setup-offline-sources.yml ./ansible # see https://github.com/wireapp/wire-server-deploy/blob/kvm_support/offline/docs.md#workaround-old-debian-key 
chmod 550 ./bin/newvm.sh
chmod 550 ./kvmhelpers/*.sh
```

### (rewrite) install qemu-kvm
KVM is the virtualization system we're using.
```
sudo apt install qemu-kvm qemu-utils -y
```

#### Ubuntu 18
If you are using ubuntu 18, you have to install the sgabios package:
```
sudo apt install sgabios -y
```

### add the demo user to the kvm group
```
sudo usermod -a -G kvm demo
```

### log out, log back in, and return to Wire-Server.

you have to logout twice, once to get out of screen, once to get out of the machine.
```
logout
logout
```

```
ssh -i ~/.ssh/id_ed25519 demo@65.21.197.76 -o serveraliveinterval=60
cd Wire-Server/
screen
```

### install bridge-utils
So that we can manage the virtual network.
```
sudo apt install bridge-utils -y
```

### (personal) install emacs
```
sudo apt install emacs-nox -y
```

### (temporary) manually create bridge device.
This is the interface we are going to use to talk to the virtual machines.
```
sudo brctl addbr br0
sudo ifconfig br0 172.16.0.1 netmask 255.255.255.0 up
```

### tell DnsMasq to provide DHCP to our KVM VMs.
```
sudo bash -c 'echo "listen-address=172.16.0.1" > /etc/dnsmasq.d/10-br0-dhcp'
sudo bash -c 'echo "dhcp-range=172.16.0.2,172.16.0.127,10m" >> /etc/dnsmasq.d/10-br0-dhcp'
sudo service dnsmasq restart
```

### enable ip forwarding.
```
sudo sed -i "s/.*net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/" /etc/sysctl.conf 
sudo sysctl -p
```

### enable network masquerading
Here, you should check the ethernet interface name for your outbound IP.

```
ip ro | sed -n "/default/s/.* dev \([en\(ps|o)0-9]*\) .*/export OUTBOUNDINTERFACE=\1/p"
```
This will return a shell command setting a variable to your default interface. copy and paste it into the command prompt, hit enter to run it, then run the following

```
sudo sed -i 's/.*DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
sudo sed -i "1i *nat\n:POSTROUTING ACCEPT [0:0]\n-A POSTROUTING -s 172.16.0.0/24 -o $OUTBOUNDINTERFACE -j MASQUERADE\nCOMMIT" /etc/ufw/before.rules
sudo service ufw restart
```

### add static IPs for VMs.
```
sudo bash -c 'echo "dhcp-host=assethost,172.16.0.128,10h" > /etc/dnsmasq.d/20-hosts'
sudo bash -c 'echo "dhcp-host=kubenode1,172.16.0.129,10h" >> /etc/dnsmasq.d/20-hosts'
sudo bash -c 'echo "dhcp-host=kubenode2,172.16.0.130,10h" >> /etc/dnsmasq.d/20-hosts'
sudo bash -c 'echo "dhcp-host=kubenode3,172.16.0.131,10h" >> /etc/dnsmasq.d/20-hosts'
sudo bash -c 'echo "dhcp-host=ansnode1,172.16.0.132,10h" >> /etc/dnsmasq.d/20-hosts'
sudo bash -c 'echo "dhcp-host=ansnode2,172.16.0.133,10h" >> /etc/dnsmasq.d/20-hosts'
sudo bash -c 'echo "dhcp-host=ansnode3,172.16.0.134,10h" >> /etc/dnsmasq.d/20-hosts'
sudo service dnsmasq restart
```

### Acquire ubuntu 18.04 server installation CD (netboot).
For the purposes of our text-only demo, we are going to use one of the netboot ISOs. this allows us to control the install from an SSH prompt.
```
curl http://archive.ubuntu.com/ubuntu/dists/bionic-updates/main/installer-amd64/current/images/netboot/mini.iso -o ubuntu.iso
```

### create assethost
```
./bin/newvm.sh -d 40 -m 1024 -c 1 assethost
```

### create kubenode1
```
./bin/newvm.sh -d 80 -m 8192 -c 6 kubenode1
```

### create kubenode2
```
./bin/newvm.sh -d 80 -m 8192 -c 6 kubenode2
```

### create kubenode3
```
./bin/newvm.sh -d 80 -m 8192 -c 6 kubenode3
```

### create ansnode1
```
./bin/newvm.sh -d 80 -m 8192 -c 6 ansnode1
```

### create ansnode2
```
./bin/newvm.sh -d 80 -m 8192 -c 6 ansnode2
```

### create ansnode3
```
./bin/newvm.sh -d 80 -m 8192 -c 6 ansnode3
```

### Start a node
Specify NOREBOOT, so the VM powers off after the install.
```
cd <nodename>
NOREBOOT=1 ./start_kvm.sh
```

when qemu starts (you see H Peter Anvin's name), hit escape.
at the " oot:" prompt, type 'expert console=ttyS0', and hit enter.

### install node
select 'choose language'
 * english
 * united states
 * united states
 * hit tab and enter to add no additional locales.
select 'Detect network hardware'
 * use tab and enter to select 'Continue' to let it install usb-storage.
select 'Configure the network'
 * no, no vlan trunking.
 * yes, Auto-configure networking.
 * use tab and enter to hit 'Continue' to select the (default) 3 seconds to detect a link.
 * supply the hostname.
   * for the assethost, type assethost
   * for the first kubernenes node, type 'kubenode1'.
   * ... etc
 * supply the domain name
   * domain name: fake.domain
Select "Choose a mirror of the ubuntu archive"
 * select http
 * select united states
 * select us.archive.ubuntu.com
 * use tab and enter to select 'Continue' for no http proxy information
select "Download installer components"
 * use tab and enter to continue, selecting no components
select "Set up Users and Passwords"
 * yes, enable shadow passwords
 * no, do not allow root login.
 * full name: demo
 * username: demo
 * password: (given by julia, same for all VMs)
 * yes, use a weak password.
 * do not encrypt home directory.
select 'configure the clock'
 * yes, set the clock using NTP
 * yes, ntp.ubuntu.com
 * yes, a berlin timezone is correct.
select 'detect disks'
select 'partition disks'
 * hit down and enter to use 'guided, use entire disk and set up LVM'.
 * pick the only option they give you for disks.
 * select 'All files in one partition'
 * yes, write the changes to disk.
 * accept the default volume group name "<hostname>-vg"
 * select 'Continue' to consume the entire disk.
 * yes, write the changes to disk.
select 'Install the base system'
 * hit enter to install the 'linux generic' kernel.
 * hit enter to chose 'generic' to install all of the available drivers.
select 'Configure the package manager'
 * Use restricted software? Yes
 * Use software from the "Universe" component? yes
 * Use software from the "Multiverse" component? yes
 * Use backported software? yes
 * Use software from the "Partner" repository? no
 * enable source repositories? No.
 * Select continue to use security archive.
select 'Select and install software'
 * use down and enter to select "Install security updates automatically"
 * scroll to the second to last item, and use space to select "OpenSSH Server", and hit continue.
select "Install the GRUB bootloader on a hard disk"
 * install the GRUB bootloader to the master boot record? yes.
 * select only device displayed (/dev/sda).
 * no to installing Extra EFI just-in-case.
select "Finish the installation"
 * yes, the clock is set to UTC
 * select continue to reboot.

### first boot
In order to 'step back' if something goes wrong later in the install, i recommend copying the empty VMs after they have shut down:
```
cp -a assethost assethost-new
cp -a ansnode1 ansnode1-new
cp -a ansnode2 ansnode2-new
cp -a ansnode3 ansnode3-new
cp -a kubenode1 kubenode1-new
cp -a kubenode2 kubenode2-new
cp -a kubenode3 kubenode3-new
```

You must have each of the virtual machines running, while installing and using wire.
I recommend using screen, and performing the following step for each image:
 * change directory to the location your VM is deployed in.
 * run "DRIVE=c ./start_kvm.sh"
 * hit escape if you want to see the boot menu.

### From this point:

switch to docs.md.

skip down to 'Making tooling available in your environment'

#### Editing the ansible inventory

##### Adding host entries
when editing the inventory, we only need seven entries in the '[all]' section. one entry for each of the VMs we are running.
Edit the 'kubenode' entries, and the 'assethost' entry like normal.

Instead of creating separate cassandra, elasticsearch, and minio entries, create three 'ansnode' entries, similar to the following:
```
ansnode1 ansible_host=172.16.0.132
ansnode2 ansible_host=172.16.0.133
ansnode3 ansible_host=172.16.0.134
```

##### Updating Group Membership
Afterwards, we need to update the lists of what nodes belong to which group, so ansible knows what to install on these nodes.

Add all three ansnode entries into the `cassandra` `elasticsearch`, and `minio` sections. They should look like the following:
```
[elasticsearch]
# elasticsearch1
# elasticsearch2
# elasticsearch3
ansnode1
ansnode2
ansnode3


[minio]
# minio1
# minio2
# minio3
ansnode1
ansnode2
ansnode3

[cassandra]
# cassandra1
# cassandra2
# cassandra3
```

Add two of the ansnode entries into the `restund` section
```
[restund]
ansnode1
ansnode2
```

Add one of the ansnode entries into the `cassandra_seed` section.
```
[cassandra_seed]
ansnode1
```

### ERROR: after you install restund, the restund firewall will fail to start.

delete the outbound rule to 172.16.0.0/12
```
sudo ufw status numbered
sudo ufw delete <right number>
```

#### enable the ports colocated services run on:
cassandra:
```
sudo ufw allow 9042/tcp
sudo ufw allow 9160/tcp
sudo ufw allow 7000/tcp
sudo ufw allow 7199/tcp
```

elasticsearch:
```
sudo ufw allow 9300/tcp
sudo ufw allow 9200/tcp
```

minio:
```
sudo ufw allow 9000/tcp
sudo ufw allow 9092/tcp
```

#### install turn pointing to port 8080



