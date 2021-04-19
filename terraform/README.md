# Terraform for wire-server

This directory contains (aspires to contain) all the Terraform required to set up
wire-server. The `environment` directory is to be considered the "root"
directory of Terraform.

## How to create a new environment

Recommended: Use nix-shell from the root of this repository to ensure that you
have the right version of terraform.

Run all commands from the top-level of this repository.

1. Export `ENV_DIR` environment variable to a directory where you want to store
   data specific to an environment. Ensure that this directory exists.

   For Wire employees, please create this directory in `cailleach/environments`
   and export its name via `ENV`. If cailleach is no checked-out as a sibling
   directory to wire-server-deploy, please instead export `ENV_DIR` as absolute
   path to the environment directory that you created.
   For the rest of this README, please consider `ENV_DIR` to be
   `$(pwd)/../cailleach/environments/${ENV}`.
1. Create backend-config in `"$ENV_DIR/backend.tfvars` which looks like this:
   ```tf
   region  = "<aws-region>"
   bucket  = "<aws-bucket>"
   key = "<s3-backend-key>"
   dynamodb_table = "<dynamodb-lock-table>"
   ```

   Please refer to [s3 backend
   docs](https://www.terraform.io/docs/backends/types/s3.html) for details.
1. Create token from Hetzner cloud and put the following contents (including the export)
    in a file called `$ENV_DIR/hcloud-token.dec`<sup>[1]</sup>:
   ```
   export HCLOUD_TOKEN=<token>
   ```
1. Create ssh key-pair, put the private key in a file called
   `$ENV_DIR/operator-ssh.dec`<sup>[1]</sup>. Example:

   ```bash
   ssh-keygen -o -a 100 -t ed25519 -f "$ENV_DIR/operator-ssh.dec" -C "example@example.com"
   # see footnote 2 if you're a wire employee
   ```
1. (optional) encrypt files if collaborating using SOPS:
   ```
   sops -e "$ENV_DIR"/operator-ssh.dec > "$ENV_DIR"/operator-ssh
   sops -e "$ENV_DIR"/hcloud-token.dec > "$ENV_DIR"/hcloud-token
   ```
1. Create variables for the environment in `$ENV_DIR/terraform.tfvars`, example:
   ```tf
   environment = <env>
   root_domain = "example.com"
   operator_ssh_public_keys = {
      terraform_managed = {
        "<key name>" = "<public key from step above>"
      }
      preuploaded_key_names = []
   }
   ```
   Delete operator-ssh.dec.pub.
   Please refer to variable definitions in `environment/*.vars.tf` in order to see which
   ones are available. Additional examples can be found in the `examples` folder at the
   root of this repository.
1. Initialize and apply Terraform
   ```
   make apply
   ```
1. Create inventory
   ```
   make generate-inventory
   ```
1. To bootstrap the nodes, please refer to the [Ansible README](../ansible/README.md)
1. To deploy Wire on top, please refer to the [Helm README](../helm/README.md)

<sup>[1]</sup>For wire employees: Encrypt this file using `sops`, it will not
work in the `nix-shell`, so change shell as needed.

<sup>[2]</sup>For wire employees: Use "backend+${ENV}-operator@wire.com" as a
convention.

## Decommissioning machines

### SFT

Each SFT server has a unique identifier. Decommissioning is as easy as removing that
identifier from one of the list - preferably from the non-active group.

### Kubernetes

Defining Kubernetes machines, is done by defining *group(s)* of machines. In order
to destroy a single machine, one has to decommission the entire group - preferably
after bringing up another group taking its place.
