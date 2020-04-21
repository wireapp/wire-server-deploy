# Example terraform scripts

Adapt to your needs as necessary.

## create-infrastructure.tf
This terraform script can be used to create a few virtual machines on the hetzner cloud provider, and generate an inventory file to use with ansible. (see: wire-server-deploy/ansible/ )

## offline.tf
This terraform script creates a complete VPC for hosting wire. It has been used in the 'Offline' environment. (see: wire-server-deploy-networkless/vpc/README.md)