# Scope

This document gives exact instructions for performing an offline demo installation of Wire on a single dedicated Hetzner server. It uses the KVM based virtual machine system to create all of the required virtual machines.

Bootstrapping a single dedicated Hetzner server for virtual machine deployment, the wire-server-deploy artifact download as well as the wire-server k8s installation have been fully automated.

## Use the hetzner robot console to create a new server.

Select Ubuntu 22.04.2 on an ax101 dedicated server. Make sure you provide a public key in the Hetzner console which can be used for ansible deployment.

If not using Hetzner, for reference, the specs of the ax101 server are:

- AMD Ryzen™ 9 5950X
- 128 GB DDR4 ECC RAM
- 2 x 3.84 TB NVMe SSD Datacenter Edition (software RAID 1)
- 1 GBit/s port

The main public IPv4 address of the Hetzner server to connect to with SSH / ansible can be found in the "Server" tab in the Hetzner Robot console, next to the Server Name.
As soon as the initial Hetzner server deployment is finished, we'll use Ansible to further provision the system.

## Automated full install

If you wish to set up "Wire in a box" for demo or testing purposes, use the script [autodeploy.sh](../bin/autodeploy.sh). It supports several config flags, which can be reviewed by calling the script using a helper flag:

```bash
autodeploy.sh -h
```

Running the script against a valid dedicated (Hetzner) server will install a fully functioning "Wire in a box" demo environment, based on the instructions provided in [docs_ubuntu_22.04.md](docs_ubuntu_22.04.md) and [coturn.md](coturn.md).

This process takes approximately 90 minutes. If this script suits your needs and the installation is a success, there's no need to follow the individualized instructions below.


## Adjust ansible playbook vars as needed

Take a look at the "vars:" section in wire-server-deploy/ansible/hetzner-single-deploy.yml and adjust vars as needed. Example:
```
  vars:
    artifact_hash: 452c8d41b519a3b41f22d93110cfbcf269697953
    ubuntu_version: 22.04.3
    ssh_pubkey: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDPTGTo1lTqd3Ym/75MRyQvj8xZINO/GI6FzfIadSe5c backend+hetzner-dedicated-operator@wire.com"
```

The variable 'artifact_hash' above is the hash of your deployment artifact, given to you by Wire, or acquired by looking at the build job.

## Run ansible playbook for server bootstrapping

Navigate to the ansible folder in wire-server-deploy and execute the playbook using valid vars as described above.
```
~ ❯ cd wire-server-deploy/ansible
~ ❯ ansible-playbook hetzner-single-deploy.yml -i root@$HETZNER_IP, --diff
```
Please note and include the trailing comma when invoking the playbook. Playbook execution might take a few minutes, especially when downloading and unpacking a new artifact.

The playbook will install baseline defaults (packages, firewall, SSH config, SSH key(s), user(s)), download & extract wire-server-deploy and download the specified ubuntu ISO.
The playbook is written to be idempotent; eg. files won't be redownloaded as long as they already exist on the target host. Deploying a new version of "wire-server-deploy" is as easy as removing the folder from the target host and updating the "artifact_hash" variable in the playbook.

At this point it's recommended to reboot the server once.

## Create VMs

SSH into the target host as demo@$HETZNER_IP and execute wire-server-deploy/bin/offline-vm-setup.sh
```
demo@Ubuntu-2204-jammy-amd64-base:~$ cd wire-server-deploy/
demo@Ubuntu-2204-jammy-amd64-base:~/wire-server-deploy$ bin/offline-vm-setup.sh
```
Without arguments, the script will deploy seven VMs behind the default libvirt network (virbr0, 192.168.122.0/24).

 * assethost - IP: 192.168.122.10
 * kubenode1 - IP: 192.168.122.21
 * kubenode2 - IP: 192.168.122.22
 * kubenode3 - IP: 192.168.122.23
 * ansnode1  - IP: 192.168.122.31
 * ansnode2  - IP: 192.168.122.32
 * ansnode3  - IP: 192.168.122.33

This will take up to 15 min (longer if the server still builds its MD RAID in the background). Once all VMs are deployed, they should be shut off. Status can be checked with:
```
demo@Ubuntu-2204-jammy-amd64-base:~$ sudo virsh list --all
```

Hint: If your local machine is running Linux, use "virt-manager" to connect to the Hetzner server and make VM administration more comfortable.

Start all VMs:

```
demo@Ubuntu-2204-jammy-amd64-base:~$ sudo bash -c "
set -e;
virsh start assethost;
virsh start kubenode1;
virsh start kubenode2;
virsh start kubenode3;
virsh start ansnode1;
virsh start ansnode2;
virsh start ansnode3;
"
```

## Access VMs

VMs created with offline-vm-setup.sh are accessible via SSH with two public keys.
 * Existing key from ~/.ssh/authorized_keys (externally via ProxyJump)
 * Local keypair key from ~/.ssh/id_ed25519 (Keypair on dedicated server)

To use your own key, use SSH with ProxyJump, as it's the more secure alternative compared to Key Forwarding ("ssh -A"):
```
~ ❯ ssh demo@192.168.122.XXX -J demo@$HETZNER_IP
```

Or just use the local keypair, created by offline-vm-setup.sh inside the dedicated server:
```
demo@Ubuntu-2204-jammy-amd64-base:~$ ssh assethost
```

Hint: resolving VM hostnames from inside the dedicated server should work, since the script is appending entries to /etc/hosts during VM creation.
But this does not work for resolving hostnames between VMs at this point. We'll be using IP addresses only going forward.

### To get a domain for WIAB experimentation

using: https://github.com/Gandi/gandi.cli

```
sudo apt install pipx
pipx install gandi-cli
pipx ensurepath
(logout, log back in)
```

```
gandi setup
```
the API key from the gandi web interface should be entered in the "Api key (rest)" and "Api key (xmlrpc)".

If you need to nuke it, it's stored in ~/.config/gandi/config.yaml

Once this is set up properly, you should be able to "gandi dns list <domain>", for domains you own with gandi.

I then built the following shell script.

domains-kittensonfire.sh
```
#!/bin/bash
domains="nginz-https nginz-ssl webapp assets account teams federator"
sft_domains="sftd"
ipaddr=65.109.105.243

# one of the staging SFT servers.
sft_ipaddr=168.119.168.239

# update the domain itsself
gandi dns update kittensonfire.com -ttl 600 @ A $ipaddr

# update subrecords of kittensonfire.com
for each in $domains; do
    gandi dns update kittensonfire.com --ttl 600 $each A $ipaddr
    sleep 5
done

# separately update the SFT subrecords of kittensonfire.com
for each in $sft_domains; do
    gandi dns update kittensonfire.com --ttl 600 $each A $sft_ipaddr
    sleep 5
done
```

### From this point:

Switch to [the Ubuntu 22.04 Wire install docs](docs_ubuntu_22.04.md)
