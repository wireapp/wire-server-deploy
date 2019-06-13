# ansible-based configuration

In a production environment, some parts of the wire-server infrastructure (such as e.g. cassandra databases) are best configured outside kubernetes. Additionally, kubernetes can be rapidly set up with kubespray, via ansible.
The documentation and code under this folder is meant to help with that.

<!-- vim-markdown-toc GFM -->

* [Status](#status)
* [Assumptions](#assumptions)
* [Dependencies](#dependencies)
* [Provision virtual machines](#provision-virtual-machines)
* [Configuring virtual machines](#configuring-virtual-machines)
    * [All VMs](#all-vms)
        * [WARNING: host re-use](#warning-host-re-use)
        * [Authentication](#authentication)
        * [ansible pre-kubernetes](#ansible-pre-kubernetes)
    * [Installing kubernetes](#installing-kubernetes)
    * [Cassandra](#cassandra)
    * [ElasticSearch](#elasticsearch)
    * [Minio](#minio)
    * [Restund](#restund)
    * [Installing helm charts - prerequisites](#installing-helm-charts---prerequisites)
    * [tinc](#tinc)

<!-- vim-markdown-toc -->

## Status

work-in-progress

- [ ] document networking setup
- [ ] diagram
- [ ] other assumptions?
- [x] install kubernetes with kubespray
- [x] install cassandra
- [x] install elasticsearch
- [x] install minio
- [ ] install redis
- [x] install restund servers
- [ ] polish

## Assumptions

This document assumes

* a bare-metal setup (no cloud provider)
* a production setup where 30 minutes of downtime is unacceptable
* about 1000 active users
* all VMs run ubuntu 16.04 or ubuntu 18.04

## Dependencies

* Install 'poetry' (python dependency management). See also the [poetry documentation](https://poetry.eustace.io/).

This assumes you're using python 2.7 (if you only have python3 available, you may need to find some workarounds):

```
sudo apt install -y python2.7 python-pip
curl -sSL https://raw.githubusercontent.com/sdispater/poetry/master/get-poetry.py > get-poetry.py
python2.7 get-poetry.py
source $HOME/.poetry/env
ln -s /usr/bin/python2.7 $HOME/.poetry/bin/python
```

* Install the python dependencies to run ansible.

```
git clone https://github.com/wireapp/wire-server-deploy.git
cd wire-server-deploy/ansible
## (optional) if you need ca certificates other than the default ones:
# export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
poetry install
```

* download the ansible roles necessary to install databases and kubernetes

```
make download
```

## Provision virtual machines

Create the following:

| Name          | Amount | CPU | memory | disk   |
| ----          | --     | --  | --     | ---    |
| cassandra     | 3      | 1   | 2 GB   | 60 GB  |
| minio         | 3      | 1   | 2 GB   | 100 GB |
| elasticsearch | 3      | 1   | 2 GB   | 10 GB  |
| redis         | 3      | 1   | 2 GB   | 10 GB  |
| kubernetes    | 3      | 4   | 8 GB   | 20 GB  |
| turn          | 2      | 1   | 2 GB   | 10 GB  |

It's up to you how you create these VMs - kvm on a bare metal machine, VM on a cloud provider, etc. Make sure they run ubuntu 16.04/18.04.

Ensure that your VMs have IP addresses that do not change.

## Configuring virtual machines

### All VMs

Copy the example hosts file:

`cp hosts.example.ini hosts.ini`

* replace the `ansible_host` values (`X.X.X.X`) with the IPs that you can reach by SSH.
* replace the `ip` values (`Y.Y.Y.Y`) with the IPs which you wish kubernetes to provide services on.

#### WARNING: host re-use

The playbooks mess with the hostnames of their targets.  You MUST pick different (virtual) hosts for the different playbooks.  If you e.g. want to run C* and k8s on the same 3 machines, the hostnames will be overwritten by the second installation playbook, corrupting the first.

#### Authentication

* if you want to use passwords:

```
sudo apt install sshpass
```

* in hosts.ini, uncomment the 'ansible_user = ...' line, and change '...' to the user you want to login as.
* in hosts.ini, uncomment the 'ansible_ssh_pass = ...' line, and change '...' to the password for the user you are logging in as.
* in hosts.ini, uncomment the 'ansible_become_pass = ...' line, and change the ... to the password you'd enter to sudo.

#### ansible pre-kubernetes
Now that you have a working hosts.ini, and you can access the host, run any ansible scripts you need, in order for the nodes to have internet (proxy config, ssl certificates, etc).

### Installing kubernetes

```
poetry run ansible-playbook -i hosts.ini kubernetes.yml -vv
```

### Cassandra

* Set variables in the hosts.ini file under `[cassandra:vars]`. Most defaults should be fine, except maybe for the cluster name and the network interface to use:

```ini
[cassandra:vars]
## set to True if using AWS
is_aws_environment = False
# cassandra_clustername: default

[all:vars]
## Set the network interface name for cassandra to bind to if you have more than one network interface
# cassandra_network_interface = eth0
```

(see [defaults/main.yml](https://github.com/wireapp/ansible-cassandra/blob/master/defaults/main.yml) for a full list of variables to change if necessary)

Install cassandra:

```
poetry run ansible-playbook -i hosts.ini cassandra.yml -vv
```

### ElasticSearch

* In your 'hosts.ini' file, in the `[elasticsearch:vars]` section, set 'elasticsearch_network_interface' to the name of the interface you want elasticsearch nodes to talk to each other on. For example:

```ini
[all:vars]
# default first interface on ubuntu on kvm:
elasticsearch_network_interface=ens3
```

* Use poetry to run ansible, and deploy ElasticSearch:
```
poetry run ansible-playbook -i hosts.ini elasticsearch.yml -vv
```

### Minio

* In your 'hosts.ini' file, in the `[all:vars]` section, make sure you set the 'minio_network_interface' to the name of the interface you want minio nodes to talk to each other on. The default from the playbook is not going to be correct for your machine. For example:

```ini
[all:vars]
# Default first interface on ubuntu on kvm:
minio_network_interface=ens3
```

* In your 'hosts.ini' file, in the `[minio:vars]` section, ensure you set minio_access_key and minio_secret key.

* Use poetry to run ansible, and deploy Minio:
```
poetry run ansible-playbook -i hosts.ini minio.yml -vv
```

### Restund

Set other variables in the hosts.ini file under `[restund:vars]`. Most defaults should be fine, except for the network interfaces to use:

* set `ansible_host=` under the `[all]` section to the IP for SSH access.
* (optional) set `restund_network_interface = ` under the `[restund:vars]` section to the interface name you wish the process to use. Defaults to the default_ipv4_address, or `eth0`.
* (optional) set `public_ipv4=` to the public IP that you wish to advertise to Wire clients (android, web, etc). This might be different than the IPs visible to the VM. This defaults to the ip of the machine in the `restund_network_interface`.

```ini
[all]
(...)
# * 'public_ipv4'  is the public IP to advertise if different than the
#                  network interface to bind to.
restund01         ansible_host=X.X.X.X public_ipv4=Y.Y.Y.Y

(...)

[restund:vars]
## Set the network interface name for restund to bind to if you have more than one network interface
## If unset, defaults to the ansible_default_ipv4 (if defined) otherwise to eth0
# restund_network_interface = eth0
```

(see [defaults/main.yml](https://github.com/wireapp/ansible-restund/blob/master/defaults/main.yml) for a full list of variables to change if necessary)

Install restund:

```
poetry run ansible-playbook -i hosts.ini restund.yml -vv
```

### Installing helm charts - prerequisites

The `helm_external.yml` playbook can be used to write the IPs of the databases into the `values/cassandra-external/values.yaml` file, and thus make them available for helm and the `...-external` charts (e.g. `cassandra-external`).

Ensure to define the following in your hosts.ini under `[all:vars]`:

```ini
[all:vars]
minio_network_interface = ...
cassandra_network_interface = ...
elasticsearch_network_interface = ...
redis_network_interface = ...
```

```
poetry run ansible-playbook -i hosts.ini -vv --diff helm_external.yml
```

Now you can install the helm charts.

### tinc

Installing [tinc mesh vpn](http://tinc-vpn.org/) is **optional and experimental**. It allows having a private network interface `vpn0` on the target VMs.

_Note: Ensure to run the tinc.yml playbook first if you use tinc, before other playbooks._

* Add a `vpn_ip=Z.Z.Z.Z` item to each entry in the hosts file with a (fresh) IP range if you wish to use tinc.
* Add a group `vpn`:

```ini
# this is a minimal example
[all]
server1 ansible_host=X.X.X.X vpn_ip=10.10.1.XXX
server1 ansible_host=X.X.X.X vpn_ip=10.10.1.YYY

[cassandra]
server1
server2

[vpn:children]
cassandra
# add other server groups here as necessary
```

Configure the physical network interface inside tinc.yml if it is not `eth0`. Then:

```
poetry run ansible-playbook -i hosts.ini tinc.yml -vv
```
