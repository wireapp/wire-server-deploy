# Ansible-based deployment

In a production environment, some parts of the wire-server infrastructure (such as e.g. cassandra databases) are best configured outside kubernetes. Additionally, kubernetes can be rapidly set up with a project called kubespray, via ansible.

This directory hosts a range of ansible playbooks to install kubernetes and databases necessary for wire-server. For documentation on usage, please refer to the [Administrator's Guide](https://docs.wire.com), notably the production installation.


## Bootrap environment created by `terraform/environment`

1. Ensure `$ENV_DIR/operator-ssh.dec` exists and contains ssh key for the
   environment.
1. Ensure that `make apply` has been run for the environment. Please refer to
   [terraform docs](../terraform/README.md) for details about how to run this.
1. Running `make bootstrap ENV=$ENV` from this directory will bootstrap the whole environment.
