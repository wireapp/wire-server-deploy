# Scope

This document gives exact instructions for performing an offline installation of Wire on a single VM from Hetzner. it uses the KVM based virtual machine system to create all of the required virtual machines.

Bootstrapping a single dedicated Hetzner server for virtual machine deployment as well as wire-server-deploy artifact download has largely been automated with ansible and bash.

## Use the hetzner robot console to create a new server.

Select Ubuntu 22.04.2 on an ax101 dedicated server. If possible, please already provide a public key in the Hetzner console which can be used for ansible deployment.

If not using Hetzner, for reference, the specs of the ax101 server are:

- AMD Ryzen™ 9 5950X
- 128 GB DDR4 ECC RAM
- 2 x 3.84 TB NVMe SSD Datacenter Edition (software RAID 1)
- 1 GBit/s port

Please note the public IP of the newly provisioned server, as it's used for the ansible playbook run.

## Pre-requisites (ansible)

Make sure to have ansible available on your local computer with a recent version (eg. 2.14.9 as of 2024-01).

## Adjust playbook vars as needed

Take a look at the "vars:" section in wire-server-deploy/ansible/hetzner-single-deploy.yml and adjust vars as needed. Example:
```
  vars:
    artifact_hash: a6e0929c9a5f4af09655c9433bb56a4858ec7574
    ubuntu_version: 22.04.3
    ssh_pubkey: "ssh-ed25519 AAAAC3Nz_CHANGEME_TE5AAAA_CHANGEME_cRpDu8vNelUH+changeme/OWB50Rk5GP jane.doe@example.com"
```

## Run ansible playbook for server bootstrapping

```
cd wire-server-deploy/ansible
ansible-playbook hetzner-single-deploy.yml -i root@$HETZNER_IP, --diff
```
Please note and include the trailing comma when invoking the playbook.

The playbook will install baseline defaults (packages, firewall, SSH config, SSH key(s), user(s)), download & extract wire-server-deploy and download the specified ubuntu ISO.
The playbook is written to be idempotent; eg. files won't be redownloaded as long as they already exist on the target host. Deploying a new version of "wire-server-deploy" is as easy as removing the folder from the target host and updating the "artifact_hash" variable in the playbook.

## Create VMs

SSH into the target host as demo@$HETZNER_IP and execute wire-server-deploy/bin/offline-vm-setup.sh
```
demo@Ubuntu-2204-jammy-amd64-base:~$ cd wire-server-deploy/
demo@Ubuntu-2204-jammy-amd64-base:~/wire-server-deploy$ bin/offline-vm-setup.sh
```
Without arguments, the script will deploy seven VMs behind the default libvirt network (virbr0, 192.168.122.0/24).

 * assethost
 * kubenode1
 * kubenode2
 * kubenode3
 * ansnode1
 * ansnode2
 * ansnode3

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

VMs created with offline-vm-setup.sh are accessible via SSH with the public key which was deployed to the "demo" user in the ansible playbook. In order to access individual VMs, use SSH with ProxyJump:

```
~ ❯ ssh demo@192.168.122.XXX -J demo@$HETZNER_IP
```

## TODO - clarify if Docker daemon on Hetzner server can be installed via "apt install docker.io" or needs to be installed from the artifact archive, like so:
```
demo@Ubuntu-2204-jammy-amd64-base:~/wire-server-deploy$ tar -xf debs-jammy.tar
```

```
demo@Ubuntu-2204-jammy-amd64-base:~/wire-server-deploy$ sudo bash -c '
set -eo pipefail;

apt -y install iptables;
dpkg -i debs-jammy/public/pool/main/d/docker-ce/docker-ce-cli_*.deb;
dpkg -i debs-jammy/public/pool/main/c/containerd.io/containerd.io_*.deb;
dpkg -i debs-jammy/public/pool/main/d/docker-ce/docker-ce_*.deb;
dpkg --configure -a;
'
```

### From this point:

switch to docs_ubuntu_22.04.md.
