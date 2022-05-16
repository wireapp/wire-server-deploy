# Setting up a KVM network for WIRE:

## Scope of this document:

This document and the files contained in this directory contain instructions and code for setting up KVM virtual hosts and virtual networking, for the testing of WIRE and its dependencies.

## Assumptions:

We're going to assume basic command line skills, and that you have installed some version of ubuntu, debian, or a debian derivative on a machine you plan on using as a hypervisor.

## Installing KVM Virtual Machines

### Preparation

#### Verifying KVM extensions, and enabling them.

First, make sure KVM is available and ready to use.

* To see if your CPUs support it, see: https://vitux.com/how-to-check-if-your-processor-supports-virtualization-technology/
  * We recommend method '2'.
  * If method 2 does not tell you "KVM acceleration can be used", try method 3. If method 3 works, but method 2 does not, you need to enable virtualization in your BIOS.
  * For loose directions on enabling virtualization in your BIOS, follow https://www.bleepingcomputer.com/tutorials/how-to-enable-cpu-virtualization-in-your-computer-bios/ .

#### Install QEMU:

QEMU is the application that lets us take advantage of KVM extensions.

* To install QEMU:
```
sudo apt install qemu-kvm
```

##### Configuring a non-priviledged user

QEMU can be run as a user (suggested for security, but more complicated) or as the 'root' user.

* If you want to run QEMU as a user, add your user to the 'kvm' system group, and ensure your user is in the sudo group.

```
# usermod -a -G sudo <username>
$ sudo usermod -a -G kvm <username>
```

Make sure you log out, and back in again afterwards, to make these group changes take effect..

#### Network Plans:

When setting up a fake network of VMs for wire, there are several ways you can hook up the VMs to each other, network wise.

for the purposes of this document, we are going to use:
host <-> proxybox
            |
         admin
            |
         kubenode1
            |
         kubenode2
            |
         kubenode3
            |
         ansnode1
            |
         ansnode2
            |
         ansnode3

This is to say, we are going to create a proxy machine which will be the only thing with internet access. In addition to this machine, we will have one node for administration tasks(during the install, and for maintainence activities), three for kubernetes, and three for non-kubernetes services, managed by ansible.

We are going to refer to this as 'network plan 1'.

### Preparing to install ubuntu on KVM

* Make a directory for containing each of your virtual machines, inside of a directory. For example, to create the directories for network plan 1:
```
mkdir kvm
mkdir kvm/proxybox
mkdir kvm/admin
mkdir kvm/kubenode1
mkdir kvm/kubenode2
mkdir kvm/kubenode3
mkdir kvm/ansnode1
mkdir kvm/ansnode2
mkdir kvm/ansnode3
```

* Change into the kvm directory, and download an ubuntu iso:
```
cd kvm/
wget http://releases.ubuntu.com/18.04/ubuntu-18.04.3-live-server-amd64.iso
```

* Create a virtual hard disk image, to serve as the disk of each of our virtual machines. we're going to make each disk the same, 20 Gigabytes:
```
sudo apt install qemu-utils
cd kvm
qemu-img create proxybox/drive-c.img 20G
qemu-img create admin/drive-c.img 20G
qemu-img create kubenode1/drive-c.img 20G
qemu-img create kubenode2/drive-c.img 20G
qemu-img create kubenode3/drive-c.img 20G
qemu-img create ansnode1/drive-c.img 20G
qemu-img create ansnode2/drive-c.img 20G
qemu-img create ansnode3/drive-c.img 20G
```

### Copying helper scripts:

The repository this file is in (https://github.com/wireapp/wire-server-deploy-networkless.git) contains this README.md. Along side it are helper scripts, for managing QEMU and it's network interfaces.

The helper scripts consist of all of the files in the directory containing this readme that end in '.sh'. Copy them into the directories you are using to contain your virtual machines. For instance, with this repo checked out under our home directory in ~/wire-app/wire-server-deploy-networkless:

```
cd kvm
cp ~/wire-app/wire-server-deploy-networkless/kvmhelpers/*.sh proxybox
cp ~/wire-app/wire-server-deploy-networkless/kvmhelpers/*.sh admin
cp ~/wire-app/wire-server-deploy-networkless/kvmhelpers/*.sh kubenode1
cp ~/wire-app/wire-server-deploy-networkless/kvmhelpers/*.sh kubenode2
cp ~/wire-app/wire-server-deploy-networkless/kvmhelpers/*.sh kubenode3
cp ~/wire-app/wire-server-deploy-networkless/kvmhelpers/*.sh ansnode1
cp ~/wire-app/wire-server-deploy-networkless/kvmhelpers/*.sh ansnode2
cp ~/wire-app/wire-server-deploy-networkless/kvmhelpers/*.sh ansnode3
```

#### Choosing a user interface:
If the system you are using has a graphical interface, and you elected to set up QEMU to be used by a non-priviledged user, these helper scripts will use the graphical interface by default. If one of these conditions is not true, Then this scripts will use the ncurses (text) interface. Should it chose wrong, there are settings in each start_kvm.sh script that you can change.

#### Choosing networking, Ram, CPUs, and boot media:

If you edit the 'start_kvm.sh' script in any of the directories that we're using to contain a VM, there are self-explaining configuration options at the top of the file. So let me explain them. :)

* The first user-editable option is MEM, or how much ram you want to give your VM, in megabytes. At present, our testing requires 6144MB for ansnode[1-3], 3072MB for kubenode[1-3], and 2048MB for the admin node and proxybox.
* The second option is CPUS, which sets how many CPUs you can see from inside of the VM. Note that this is not a hard reservation, so you can have up to two CPUs for each of your VMs, even if you only have two physical CPUs.
* The third and forth options are what files to use as the virtual cd-rom and virtual hard disks.

The final two options we're going to examine configure the networking. For each network card in our VM, there is a coresponding "eth<number>=<STRATEGY>" line. There are currently two strategies available:
  * HOSTBRIDGE -- This network interface is for the VM to talk over ethernet to the machine the VM is running on.
  * GUESTBRIDGE -- This network interface is connected to a virtual switch, which has any other VM that uses this strategy also plugged into it.

Following our example network plan, we're going to leave proxybox with one interface configured for HOSTBRIDGE so it has internet access, and one interface configured for GUESTBRIDGE, so the machines we are installing wire on can communicate with it. we are going to comment out the HOSTBRIDGE interface on all other VMs, so that they only speak to the proxybox, via the GUESTBRIDGE.

#### Configuring the physical host to provide networking:

* Install bridge-utils, for GUESTBRIDGE and HOSTBRIDGE to work.
```
sudo apt install bridge-utils
```

##### LocalHost -> KVM
== Skip this entire step if we are not providing internet and IP connectivity to any VM, AKA if you are not using HOSTBRIDGE ==

For HOSTBRIDGE, we are going to install and configure an ip-masquerading firewall, a DHCP server, and a DNS server, so that VMs using the HOSTBRIDGE strategy can access the internet, through services on the host machine.

* Install dependencies. the UFW firewall, ISC's DHCP server, and the Bind nameserver:
```
sudo apt install ufw isc-dhcp-server bind9
```

* make sure we can connect on port 22 tcp so we can ssh into the hypervisor from the outside world, and from machines using HOSTBRIDGE.
```
sudo ufw allow 22/tcp
```

###### Sharing Bridge Devices:
Each networking strategy requires ownership of a bridge device, in order to do it's work. by default, these scripts are set up with 'br0' owned by the HOSTBRIDGE strategy, and 'br1' owned by the GUESTBRIDGE strategy. This is fine if you're the only one on the box, and you only want to follow these directions one time. If someone else is using br0 or br1, or has followed these instructions, you're going to need to change the bridge devices assigned to the strategies for the network plan you're installing.

Assuming someone else, or you, have followed these instructions already, and you don't want to interfere with the 'other' set of strategies, go to each HOSTBRIDGE-vars.sh, and change the 'BRIDGE=br0' line to read 'BRIDGE=br2'. Likewise, go to each GUESTBRIDGE-vars.sh file, and change 'BRIDGE=br1' to 'BRIDGE=br3'. This will ensure you don't interfere with the br0 and br1 owned by the strategies of the already installed scripts.

Or, if you trust my quick and dirty sed/bash scripts:
```
for each in $(find ./ -name HOSTBRIDGE-vars.sh) ; do { sed -i "s/BRIDGE=br0/BRIDGE=br2/" $each ; } done;
for each in $(find ./ -name GUESTBRIDGE-vars.sh) ; do { sed -i "s/BRIDGE=br1/BRIDGE=br3/" $each ; } done;
```

###### Sharing internet on the HOSTBRIDGE via IP Masquerading

We're using the [UFW](https://wiki.debian.org/Uncomplicated%20Firewall%20%28ufw%29) product to provide internet to any machine using the HOSTBRIDGE strategy. similar to the 'Sharing Bridge Devices' step, we're going to have to be a bit aware of our neighbors when picking an IP block to use between the physical machine, and virtual machines on HOSTBRIDGE. We're also going to have to pick something that does not conflict with any of the other interfaces on this machine, lest we accidentally mess up routing for the interface we use to get internet, and access TO the machine.

Usually, I pick '172.16.0/24' as a safe default. docker picks '172.17.0/24', so i suggest avoiding that. for an idea what your options are, look at the interface of the machine you're getting internet acces via, and see if it's on a [Private Network](https://en.wikipedia.org/wiki/Private_network). Select a '/24' network (that is, a range of 255 IPs in a block, in one of the Private IPv4 address ranges) that none of your coworkers are using on this box, and use it for the following steps.

####### Configuring HOSTBRIDGE-vars.sh

Once you have selected the IP subnet you're going to use on your HOSTBRIDGE, you need to change some settings in HOSTBRIDGE-vars.sh. specifically:
```
# The IP of the host system, on the host<->VM network. where we should provide services (dhcp, dns, ...) that the VMs can see.
BRIDGEIP=172.16.0.1
# The broadcast address for the above network.
BRIDGEBROADCAST=172.16.0.255
```

As with the last step, to change these, you can either edit each HOSTBRIDGE-vars.sh file, or use some quick and dirty sed/bash scripts:
```
for each in $(find ./ -name HOSTBRIDGE-vars.sh) ; do { sed -i "s/BRIDGEIP=172.16.0.1/BRIDGEIP=172.18.0.1/" $each ; } done;
for each in $(find ./ -name HOSTBRIDGE-vars.sh) ; do { sed -i "s/BRIDGEBROADCAST=172.16.0.255/BRIDGEBROADCAST=172.18.0.255/" $each ; } done;
```

####### Configuring IP Masquerading

* Make sure "DEFAULT_FORWARD_POLICY=DROP" has been changed to 'DEFAULT_FORWARD_POLICY="ACCEPT"' in /etc/default/ufw

* Make sure /etc/ufw/sysctl.conf has been edited to Disable ipv6, and allow ipv4 forwarding. you should only have to uncomment the first line:
```
net.ipv4.ip_forward=1
#net/ipv6/conf/default/forwarding=1
#net/ipv6/conf/all/forwarding=1
```

* Add a 'POSTROUTING' rule in the 'NAT' table, to direct traffic bidirectionally between your HOSTBRIDGE subnet and the internet. This entry is added in /etc/ufw/before.rules. If this has not been done on this machine before, you may have to add this entire section right after the first comment block in /etc/ufw/before.rules. If this section already exists, add just the line starting with '-A POSTROUTING' into the already existing block.  Make sure to change the 'enp0s25' interface name to match the interface your machine uses to get to the internet (look at 'ip route show default'), and to use your selected HOSTBRIDGE subnet range:
```

# NAT table rules
*nat
:POSTROUTING ACCEPT [0:0]

# Masqeurade traffic from our HOSTBRIDGE network of 172.16.0/24 to enp0s25. enp0s25 is probably not the name of your network card. check, and adjust.
-A POSTROUTING -s 172.16.0/24 -o enp0s25 -j MASQUERADE

# don't delete the 'COMMIT' line or these nat table rules won't
# be processed
COMMIT
```

* Restart the firewall to enable these changes:
```
sudo ufw disable && sudo ufw enable
```

####### DHCP services:

In order for VMs plugged into the HOSTBRIDGE to get an address, they will use DHCP. We're going to configure ISC's DHCPD to provide those addresses.

* edit /etc/dhcp/dhcpd.conf
 * comment out the line at the top reading: 'option domain-name "example.org";'
 * comment out the line near the top reading: 'option domain-name-servers ns1.example.org, ns2.example.org;'
 * add the following to the end of the file, to provide addresses to your selected HOSTBRIDGE subnet range. Make sure to change the addresses to match your selected HOSTBRIDGE subnet:
```
# provide DHCP to our hosted kvm network.
subnet 172.16.0.0 netmask 255.255.255.0 {
  range 172.16.0.10 172.16.0.20;
  option routers 172.16.0.1;
  option domain-name-servers 172.16.0.1;
}
```

* Edit /etc/default/isc-dhcp-server, and Add your selected LOCALNET bridge device to the list of ipv4 interfaces dhcpd can listen to. If there is already an entry, note that spaces are used as delimeters in this list:
```
INTERFACESv4="br0"
```

* Restart isc-dhcpd-server to make changes effective:
```
sudo service isc-dhcp-server restart
```

####### Name Services:
DNS services will be handled by BIND, which is configured properly by default. The only thing we need to do is poke a hole in the firewall, so that the HOSTBRIDGEs can access it.

* add port 53 udp to the list of ports to allow remote connections from.
```
sudo ufw allow 53/udp
```

##### GUESTBRIDGE:

As no services from the host are available on this network, nothing needs done for this.


### Launching VMs, and installing ubuntu.

You can now run each of the VMs, and perform your OS install. To perform a regular startup, booting from the ISO you have selected, change directory into one of the directories containing your VMs, and run start_kvm.sh:
```
cd kvm/proxybox/
./start_kvm.sh
```

At this point, you can install ubuntu on each of your nodes like normal.

#### Ubuntu 16.04

##### Getting a text mode installer:

###### Ubuntu 16.04 (mini ISO)
Note that the AMD64 mini iso for ubuntu 16 is broken, and will not install.

* If you want to perform your install in text mode:
```
down arrow
tab
backspace 6 times
left arrow 22 times
backspace 7 times
type 'debian-installer/framebuffer=false'
enter
```

###### Ubuntu 16.04 (official ISO)
Downloaded from: http://releases.ubuntu.com/16.04.6/ubuntu-16.04.6-server-amd64.iso

* If you want to perform your install in text mode:
```
enter
f6
escape
left arrow 5 times.
backspace 5 times.
left arrow 27 times.
backspace 7 times.
type 'debian-installer/framebuffer=false'
enter
```
##### Performing the install

Proceed with installation as normal. When you get to the 'Finish the installation' stage where it prompts you to remove the CD and reboot:
* Hit 'Go Back' to avoid rebooting. go out to the 'Ubuntu installer main menu'
* Select 'Execute a shell', and drop to a shell.
* At the shell prompt:
```
cd /target
chroot ./
apt install -y openssh-server
vi etc/default/grub
```
* Using vi, comment out the 'GRUB_CMDLINE_LINUX_DEFAULT' line, set 'GRUB_CMDLINE_LINUX' to just 'text', and uncomment the 'GRUB_TERMINAL=console' line.
* Write and Quit vi, exit the chroot, and exit the shell. You should be back in the installation menu.
* Re-run the 'Install the grub bootloader on a hard disk' step.
* Reboot.

You will have to shut down the VM to change it to booting from the hard drive, instead of the CD. to do that, you can log into another terminal, and kill -15 the qemu process.


#### Ubuntu 18.04 (official ISO)
Downloaded from: http://releases.ubuntu.com/18.04/ubuntu-18.04.3-live-server-amd64.iso

You should see '640 x 480 Graphic mode' when you start the install, but it will quickly give way to a text based installation system, by default.

### Booting your VM:

To boot into the OS:
```
DRIVE=c ./start_kvm.sh
```
