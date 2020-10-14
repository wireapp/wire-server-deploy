# Ansible-based deployment

In a production environment, some parts of the wire-server infrastructure (such as e.g. cassandra databases) are best configured outside kubernetes. Additionally, kubernetes can be rapidly set up with a project called kubespray, via ansible.

This directory hosts a range of ansible playbooks to install kubernetes and databases necessary for wire-server. For documentation on usage, please refer to the [Administrator's Guide](https://docs.wire.com), notably the production installation.


## Bootrap environment created by `terraform/environment`

An 'environment' is supposed to represent all the setup required for the Wire
backend to function.

'Bootstrapping' an environment means running a range of idempotent ansible
playbooks against servers specified in an inventory, resulting in a fully
functional environment. This action can be re-run as often as you want (e.g. in
case you change some variables or upgrade to new versions).

To start with, the environment only has SFT servers; but more will be added here
soon.

1. Please ensure `ENV_DIR` or `ENV` are exported as specified in the [docs in
   the terraform folder](../terraform/README.md)
1. Ensure `$ENV_DIR/operator-ssh.dec` exists and contains an ssh key for the
   environment.
1. Ensure that `make apply` and `make create-inventory` have been run for the
   environment. Please refer to the [docs in the terraform
   folder](../terraform/README.md) for details about how to run this.
1. Ensure all required variables are set in `$ENV_DIR/inventory/*.yml`
1. Running `make bootstrap` from this directory will bootstrap the
   environment.
