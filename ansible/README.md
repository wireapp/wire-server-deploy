# ansible-based configuration

In a production environment, some parts of the wire-server infrastructure (such as e.g. cassandra databases) are best configured outside kubernetes. The documentation and code under this folder is meant to help with that.

## Status

work-in-progress

TODO: diagram
TODO: further assumptions

## Assumtions

This document assumes 

* a bare-metal setup (no cloud provider)
* a production setup where 30 minutes of downtime is unacceptable
* about 1000 active users

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

It's up to you how you create these VMs - kvm on a bare metal machine, VM on a cloud provider, etc.

For the rest of this document, we assume these VMs run ubuntu 16.04 or ubuntu 18.04.

## Configuring virtual machines

### All VMs

Copy the example hosts file:

`cp hosts.example.ini hosts.ini`

and replace the `X.X.X.X` with the IPs that you can reach by SSH.

### cassandra

### kubernetes


