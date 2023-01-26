# Scope

This document gives exact instructions for performing an offline installation of Wire on a single VM from Hetzner. it uses the KVM virtual machine system to create all of the required virtual machines.

## Use the hetzner robot console to create a new server.

Select Ubuntu 20.04 on an ax101 dedicated server.

If not using Hetzner, for reference, the specs of the ax101 server are:

* AMD Ryzen™ 9 5950X
* 128 GB DDR4 ECC RAM
* 2 x 3.84 TB NVMe SSD Datacenter Edition (software RAID 1) 
* 1 GBit/s port

In our example, the returned IP when creating the server was: 65.21.197.76

## Pre-requisites

On your local machine if you don't have an ed25519 ssh key yet, generate one:

```
ssh-keygen -t ed25519
```

Set a variable with the IP address of the host you are setting up:

```
HOST_IP=1.2.3.4
```

Add your local ssh public key as an authorized key on the host (if not already done).
Either do via the robot or (if you have a root password) with these commands:

```
scp ~/.ssh/id_ed25519.pub "root@${HOST_IP}:"
ssh "root@${HOST_IP}" '/bin/bash -c "mkdir -p ~/.ssh/ && chmod 700 ~/.ssh/ && cat id_ed25519.pub >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && rm ~/id_ed25519.pub"'
```

Create a `site.ini` file locally. Populate it with the demo installation's actual
domain name, public IP address, the installer's email address (used for certbot),
and the URL where the wire-server can be downloaded:

```
echo WIRE_DOMAIN=example.com > site.ini
echo PUBLICIPADDRESS=1.2.3.4 >> site.ini
echo INSTALLER_EMAIL=alice.admin@provider.net >> site.ini
echo ARTIFACT_URL=https://s3-eu-west-1.amazonaws.com/public.wire.com/artifacts/wire-server-deploy-static-03fad4ff6d9a67eb56668fb259a0c1571cabcac4.tgz >> site.ini
```

## Update the host packages and create a demo user

Login to the host as root using your key instead of a password:

```
ssh -i ~/.ssh/id_ed25519 "root@${HOST_IP}" -o serveraliveinterval=60
```

Run these commands on the host (as root):

```
apt update && apt upgrade -y 
apt install -y tmate fail2ban
sed -i -re 's/^(PasswordAuthentication)(.+)/\1 no/' /etc/ssh/sshd_config
sed -i -re 's/^(UsePAM)(.+)/\1 no/' /etc/ssh/sshd_config
sed -i -re 's/^(PermitRootLogin)(.+)/\1 prohibit-password/' /etc/ssh/sshd_config
service ssh restart
adduser --disabled-password --gecos "" demo
mkdir -p ~demo/.ssh ~demo/Wire-Server
cp ~/.ssh/authorized_keys /home/demo/.ssh/
chown -R demo:demo ~demo/
chmod 700 ~demo/.ssh
usermod -a -G kvm demo
echo "demo ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/10-demo_user
chmod 440 /etc/sudoers.d/10-demo_user
reboot
```

## Download the deployment scripts and prepare and install all the kvms

Copy the site.ini file to the host:

```
scp -i ~/.ssh/id_ed25519 site.ini "demo@${HOST_IP}:Wire-Server"
```

Login to the host as the demo user:

```
ssh -i ~/.ssh/id_ed25519 "demo@${HOST_IP}" -o serveraliveinterval=60
```

Run these commands on the host (as demo):

```
sudo sed -i -re 's/^(PermitRootLogin)(.+)/\1 no/' /etc/ssh/sshd_config
sudo service ssh restart
sudo apt install -y git
cd ~/Wire-Server
git clone -b rohan/autoinstall https://github.com/wireapp/wire-server-deploy.git
wire-server-deploy/bin/install-demo.sh
```



### From this point:

switch to docs.md.

skip down to 'Making tooling available in your environment'

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
