# ansible-based configuration

In a production environment, some parts of the wire-server infrastructure (such as e.g. cassandra databases) are best configured outside kubernetes. The documentation and code under this folder is meant to help with that.

## Status

work-in-progress

- [ ] document networking setup
- [ ] diagram
- [ ] other assumptions?
- [x] install kubernetes with kubespray
- [ ] install cassandra
- [ ] install elasticsearch
- [ ] install redis
- [ ] install turn servers
- [ ] polish

## Assumptions

This document assumes

* a bare-metal setup (no cloud provider)
* a production setup where 30 minutes of downtime is unacceptable
* about 1000 active users
* all VMs run ubuntu 16.04 or ubuntu 18.04

## Development setup

```
# install 'poetry' (python dependency management)
curl -sSL https://raw.githubusercontent.com/sdispater/poetry/master/get-poetry.py | python

cd ansible
# install the python dependencies to run ansible
poetry install

# download the ansible roles necessary to install databases and kubernetes
make download
```

## Creating virtual machines

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

## Configuring virtual machines

### All VMs

Copy the example hosts file:

`cp hosts.example.ini hosts.ini`

* replace the `ansible_host` values (`X.X.X.X`) with the IPs that you can reach by SSH.
* replace the `ip` values (`Y.Y.Y.Y`) with the IPs which you wish kubernetes to bind to.

### kubernetes

```
poetry run ansible-playbook -i hosts.ini kubernetes.yml -vv
```

### cassandra

TODO

### tinc

* (optional) add a `vpn_ip=Z.Z.Z.Z` item to each entry in the hosts file with a (fresh) IP range if you wish to use [tinc mesh vpn](http://tinc-vpn.org/). Ensure to run the tinc.yml playbook first. See the Tinc section for details. 

TODO add playbook.
