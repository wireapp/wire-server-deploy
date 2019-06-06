# ansible-based configuration

In a production environment, some parts of the wire-server infrastructure (such as e.g. cassandra databases) are best configured outside kubernetes. Additionally, kubernetes can be rapidly set up with kubespray, via ansible.
The documentation and code under this folder is meant to help with that.

## Status

work-in-progress

- [ ] document networking setup
- [ ] diagram
- [ ] other assumptions?
- [x] install kubernetes with kubespray
- [ ] install cassandra
- [x] install elasticsearch
- [ ] install redis
- [ ] install turn servers
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
sudo apt install python2.7 python-pip
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
* replace the `ip` values (`Y.Y.Y.Y`) with the IPs which you wish kubernetes to bind to.

#### Authentication
* if you want to use passwords:
```
sudo apt install sshpass
```
* in hosts.ini, change the ansible_user to the user you want to login as, the ansible_ssh_pass to the password (if you require one), and the ansible_become_pass to the sudo password (if required.)

#### ansible pre-kubernetes
Now that you have a working hosts.ini, and you can access the host, run any ansible scripts you need, in order for the nodes to have internet (proxy config, ssl certificates, etc).

### kubernetes

```
poetry run ansible-playbook -i hosts.ini kubernetes.yml -vv
```

### cassandra

TODO

### ElasticSearch

* In your 'hosts.ini' file, in the `[elasticsearch:vars]` section, set 'elasticsearch_network_interface' to the name of the interface you want elasticsearch nodes to talk to each other on. For example:
```
[elasticsearch:vars]
# default first interface on ubuntu 18 on kvm:
elasticsearch_network_interface=ens3
```

* Use poetry to run ansible, and deploy ElasticSearch:
```
poetry run ansible-playbook -i hosts.ini elasticsearch.yml -vv
```

### tinc

* (optional) add a `vpn_ip=Z.Z.Z.Z` item to each entry in the hosts file with a (fresh) IP range if you wish to use [tinc mesh vpn](http://tinc-vpn.org/). Ensure to run the tinc.yml playbook first. See the Tinc section for details. 

TODO add playbook.
