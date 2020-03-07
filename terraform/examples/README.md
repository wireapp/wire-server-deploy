# Example terraform scripts

This Terraform examples can be used to create one or more virtual machines on the Hetzner cloud provider, and generate an inventory file to use with Ansible (based on `wire-server-deploy/ansible/hosts.*.ini`)

* `./single-node` - provisions one machine that to deploy a [wire-server demo](https://docs.wire.com/how-to/install/planning.html#demo-installation-trying-functionality-out)
* `./multi-node` - provisions multiple machines to deploy a [wire-server production-like reference implementation](https://docs.wire.com/how-to/install/planning.html#production-installation-persistent-data-high-availability)

Adapt to your needs as necessary.
