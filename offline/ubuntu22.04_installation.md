# Scope

This document gives exact instructions for performing an offline installation of Wire on a single VM from Hetzner. it uses the KVM based virtual machine system to create all of the required virtual machines.

This document also gives instructions for creating a TURN calling server on a separate VM.

## Use the hetzner robot console to create a new server.

Select Ubuntu 22.04.2 on an ax101 dedicated server.

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

Install `nano` or your favorite text editor:

```
sudo apt install nano -y
```

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

## Disable root login via ssh

Use sudo to edit `/etc/ssh/sshd_config`

```
sudo nano /etc/ssh/sshd_config
```

And set the following:
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
curl https://s3-eu-west-1.amazonaws.com/public.wire.com/artifacts/wire-server-deploy-static-03fad4ff6d9a67eb56668fb259a0c1571cabcac4.tgz
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
sudo ufw allow Openssh
sudo ufw enable
```

### (temporary) copy helper scripts from wire-server-deploy
```
sudo apt install git -y
git clone https://github.com/wireapp/wire-server-deploy.git -b update_to_ubuntu_22
cp -a wire-server-deploy/ansible/setup-offline-sources.yml ./ansible # see https://github.com/wireapp/wire-server-deploy/blob/kvm_support/offline/docs.md#workaround-old-debian-key 
```

### Install libvirt and dependencies
We will install libvirt to create the vms for deployment
```
sudo apt install -y qemu qemu-kvm qemu-utils libvirt-clients libvirt-daemon-system virtinst bridge-utils virt-manager
sudo systemctl enable libvirtd
sudo systemctl start libvirtd
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
sudo apt install bridge-utils net-tools -y
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

### Acquire ubuntu 22.04 server installation CD (server).
```
curl https://releases.ubuntu.com/jammy/ubuntu-22.04.2-live-server-amd64.iso -o ubuntu.iso
sudo chmod o+rx /home/demo/
```

## Create 7 vms for deployment
```
sudo mkdir -p /var/kvm/images/ # place to store the drive images for vms
```

### Create Assethost
sudo virt-install --name assethost --ram 1024 --disk path=/var/kvm/images/assethost.img,size=100 --vcpus 1 --network bridge=br0 --graphics none --console pty,target_type=serial --location /home/demo/Wire-Server/ubuntu.iso,kernel=casper/vmlinuz,initrd=casper/initrd --extra-args 'console=ttyS0,115200n8'


Continue in Basic Mode

Layout - English, Variant -> English --> Done

Ubuntu Server --> Done

Network connections --> Make suere you get something like "DHCPv4  172.16.0.8/24" --> Done

Proxy Address - dont change anything --> Done

Mirror Address - dont change anything --> Done

Guided Storage configuration - dont change anything --> Done

Storage Configuration - dont change anything --> Done

File System Summary --> Continue

 * Your name: assethost # This will be kubenode1, kubenode2 and so on for other vms..
 * Your server's name --> same as above
 * Pick a username --> demo
 * Choose a password --> # create password
 * Confirm your password --> # create a password

Upgrade to Ubuntu pro - dont change anything --> Continue

Install OpenSSH server press Space button to enable this --> Done

Featured Server snaps - dont change anything press Tab --> Done


Now installation will start, might take 5-10 minutes. Mean while you can open another tab in the screen session to create more vms in the parallel."press ctrl+a than c"

After installation --> select Reboot now --> Press Enter on seeeing message " [FAILED] Failed unmounting /cdrom."

Again press Enter until you reach the login prompt

once logged in...do

```
ip address
```

to get the ip address of this vm, this will return something like - 

```
2: enp1s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 52:54:00:d8:30:ee brd ff:ff:ff:ff:ff:ff
    inet 172.16.0.128/24 metric 100 brd 172.16.0.255 scope global dynamic enp1s0
       valid_lft 35970sec preferred_lft 35970sec
    inet6 fe80::5054:ff:fed8:30ee/64 scope link 
       valid_lft forever preferred_lft forever
```

Here 172.16.0.128 is the ip address of this vm, we will need this to configure in our ansible hosts.
Sometimes these ips are auto assigned and are not in proper range, so we make sure with above command.


You can create multiple screen terminals with ctrl+b than press c to install multiple vms in parallel.


### Create kubenode1

```
sudo virt-install --name kubenode1 --ram 8192 --disk path=/var/kvm/images/kubenode1.img,size=120 --vcpus 6 --network bridge=br0 --graphics none --console pty,target_type=serial --location /home/demo/Wire-Server/ubuntu.iso,kernel=casper/vmlinuz,initrd=casper/initrd --extra-args 'console=ttyS0,115200n8'
```

### Create kubenode2

```
sudo virt-install --name kubenode2 --ram 8192 --disk path=/var/kvm/images/kubenode2.img,size=120 --vcpus 6 --network bridge=br0 --graphics none --console pty,target_type=serial --location /home/demo/Wire-Server/ubuntu.iso,kernel=casper/vmlinuz,initrd=casper/initrd --extra-args 'console=ttyS0,115200n8'
```

### Create kubenode3

```
sudo virt-install --name kubenode3 --ram 8192 --disk path=/var/kvm/images/kubenode3.img,size=120 --vcpus 6 --network bridge=br0 --graphics none --console pty,target_type=serial --location /home/demo/Wire-Server/ubuntu.iso,kernel=casper/vmlinuz,initrd=casper/initrd --extra-args 'console=ttyS0,115200n8'
```

### Create ansnode1

```
sudo virt-install --name ansnode1 --ram 8192 --disk path=/var/kvm/images/ansnode1.img,size=80 --vcpus 6 --network bridge=br0 --graphics none --console pty,target_type=serial --location /home/demo/Wire-Server/ubuntu.iso,kernel=casper/vmlinuz,initrd=casper/initrd --extra-args 'console=ttyS0,115200n8'
```

### Create ansnode2

```
sudo virt-install --name ansnode2 --ram 8192 --disk path=/var/kvm/images/ansnode2.img,size=80 --vcpus 6 --network bridge=br0 --graphics none --console pty,target_type=serial --location /home/demo/Wire-Server/ubuntu.iso,kernel=casper/vmlinuz,initrd=casper/initrd --extra-args 'console=ttyS0,115200n8'
```

### Create ansnode3

```
sudo virt-install --name ansnode4 --ram 8192 --disk path=/var/kvm/images/ansnode4.img,size=20 --vcpus 6 --network bridge=br0 --graphics none --console pty,target_type=serial --location /home/demo/Wire-Server/ubuntu.iso,kernel=casper/vmlinuz,initrd=casper/initrd --extra-args 'console=ttyS0,115200n8'
```

## disable internet access to the vms

Replace all of ntftables.conf

```
sudo nano /etc/nftables.conf 
```

With this content:

```
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
        chain input {
                type filter hook input priority 0;
        }
        chain forward {
                type filter  hook forward priority 0;
                policy accept;
                ct state {established, related} accept comment "allow tracked connections";
                iifname "br0" oifname "enp7s0" drop comment "Drop connections that VMs try to initiate with the internet";
        }
        chain output {
                type filter hook output priority 0;
        }
}
```

Then run:

```
sudo systemctl restart nftables
```

ssh into a vm and see if you can access the internet - 

```
ping 8.8.8.8
```

the above command shouldn't receive the packets, in case internet is working than - 
restart libvirt from host machine --> sudo systemctl start libvirtd
ssh into each vm and restart them

and check again, until internet is disabled on the vms.


In rare case, if we want to enable internet access on the vms for some test related purpose, 
comment the line -- iifname "br0" oifname "enp7s0" drop comment "Drop connections that VMs try to initiate with the internet";
from nftables.conf and restart these services 
```
sudo systemctl restart nftables libvirtd systemd-machined qemu-kvm.service ufw
```

<<<<<<< Updated upstream
#### install turn pointing to port 8080
=======

### From this point:

switch to docs_ubuntu_22.04.md.
>>>>>>> Stashed changes
