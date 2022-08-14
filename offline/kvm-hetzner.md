# Scope

This document gives exact instructions for performing an offline installation of Wire on a single VM from Hetzner. it uses the KVM virtual machine system to create all of the required virtual machines.

This document also gives instructions for creating a TURN calling server on a separate VM.

## create an SSH key pair.


## use the hetzner robot console to create a new server.

select ubuntu 18.04 or ubuntu 20.04 on an ax101 dedicated server.

returned IP: 65.21.197.76

## Create demo user.

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

### use the demo user to reboot to apply security patches
This step ensures sudo is working, before you reboot the machine.
```
sudo reboot
```

## ssh in as demo user.
```
ssh -i ~/.ssh/id_ed25519 demo@65.21.197.76 -o serveraliveinterval=60
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
```
tar -xf debs.tar
```

### (FIXME: add iptables to the repo) Install Docker from debian archive.
```
sudo apt install iptables
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
sudo ufw allow in on br0 from any proto udp to any port 67
sudo ufw enable
```

### (temporary) copy helper scripts from wire-server-deploy
```
sudo apt install git -y
git clone https://github.com/wireapp/wire-server-deploy.git
cd wire-server-deploy
git checkout kvm_support
cd ..
cp -a wire-server-deploy/kvmhelpers/ ./
cp -a wire-server-deploy/bin/newvm.sh ./bin
cp -a wire-server-deploy/ansible/setup-offline-sources.sh ./ansible
chmod 550 ./bin/newvm.sh
```

### (rewrite) install qemu-kvm
KVM is the virtualization system we're using.
```
sudo apt install qemu-kvm qemu-utils -y
```

#### Ubuntu 18
If you are using ubuntu 18, you have to install the sgabios package:
```
sude apt install sgabios -y
```

### add the demo user to the kvm group
```
sudo usermod -a -G kvm demo
```

### log out, log back in, and return to Wire-Server.
```
logout
```

```
ssh -i ~/.ssh/id_ed25519 demo@65.21.197.76 -o serveraliveinterval=60
cd Wire-Server/
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
ip ro | sed -n "/default/s/.* dev \([enps0-9]*\) .*/OUTBOUNDINTERFACE=\1/p"
```
This will return a shell command setting a variable to your default interface. copy and paste it, then run the following

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
 * no additional.
select 'Detect network hardware'
 * select 'Continue' to let it install usb-storage.
select 'Configure the network'
 * no, no vlan trunking.
 * yes, Auto-configure networking.
 * hit 'Continue' to select the (default) 3 seconds to detect a link.
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
 * select 'Continue' for no http proxy information
select "Download installer components"
 * select no components, hit "Continue"
select "Set up Users and Passwords"
 * enable shadow passwords
 * do not allow root login.
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
 * guided, use entire disk and set up LVM.
 * pick the only option they give you for disks.
 * select 'All files in one partition'
 * yes, write the changes to disk.
 * accept the default volume group name "<hostname>-vg"
 * select 'Continue' to consume the entire disk.
 * yes, write the changes to disk.
select 'Install the base system'
 * install the 'linux generic' kernel.
 * chose 'generic' to install all of the available drivers.
select 'Configure the package manager'
 * Use restricted software? Yes
 * Use software from the "Universe" component? yes
 * Use software from the "Multiverse" component? yes
 * Use backported software? yes
 * Use software from the "Partner" repository? no
 * enable source repositories? No.
 * Select continue to use security archive.
select 'Select and install software'
 * select "Install security updates automatically"
 * select "OpenSSH Server", and hit continue.
select "Install the GRUB bootloader on a first disk"
 * install the GRUB bootloader to the master boot record? yes.
 * select only device displayed (/dev/sda).
 * no to installing Extra EFI just-in-case.
select "Finish the installation"
 * yes, the clock is set to UTC
 * select continue to reboot.

### first boot
 * run "DRIVE=c ./start_kvm.sh"
 * hit escape if you want to see the boot menu.


### From this point:

switch to docs.md.

skip to the step where we source the offline environment.

when editing the inventory, create 'ansnode' entries, rather than separate cassandra, elasticsearch, and minio nodes.


