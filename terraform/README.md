# Terraform for wire-server

This directory contains (aspires to contain) all the terraform required to setup
wire-server. The `environment` directory is to be considered the "root"
directory of terraform.

## How to create a new environment

Recommended: Use nix-shell from the root of this repository to ensure that you
have the right version of terraform.

Run all commands from `terraform/environment` directory.

1. Export `ENV_DIR` environment variable to a directory where you want to store
   data specific to an environment. Ensure that this directory exists.

   For Wire employees, please create this directory in `cailleach/environments`.
   If cailleach is not checked-out as a sibling directory to wire-server-deploy,
   please export `CAILLEACH_DIR` as absolute path to the cailleach directory.
   Additionally, export `ENV` as the name of the environment. For the rest of
   this README, please consider `ENV_DIR` to be
   `${CAILLEACH_DIR}/environments/${ENV}`.
1. Create backend-config in `"$ENV_DIR/backend.tfvars` which looks like this:
   ```tf
   region  = "<aws-region>"
   bucket  = "<aws-bucket>"
   key = "<s3-backend-key>"
   dynamodb_table = "<dynamodb-lock-table>"
   ```

   Please refer to [s3 backend
   docs](https://www.terraform.io/docs/backends/types/s3.html) for details.
1. Create token from hetzner cloud and put the following contents (including the export) 
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
1. Create variables for the environment in `$ENV_DIR/terraform.tfvars`, example:
   ```tf
   environment = <env>
   sft_server_names = ["1", "2"]
   root_domain = "example.com"
   operator_ssh_public_key = <public key from step above>
   ```
   Delete operator-ssh.dec.pub.
1. Initialiaze terraform
   ```
   make init ENV=$ENV
   ```
1. Apply terraform
   ```
   make apply ENV=$ENV
   ```
1. To bootstrap the nodes, please refer to the [ansible README](../ansible/README.md)

<sup>[1]</sup>For wire employees: Encrypt this file using `sops`, it will not
work in the `nix-shell`, so change shell as needed.

<sup>[2]</sup>For wire employees: Use "backend+${ENV}-operator@wire.com" as a
convention.
