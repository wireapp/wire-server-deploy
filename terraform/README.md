# Terraform for wire-server

This directory contains (aspires to contain) all the terraform required to setup
wire-server. The `environment` directory is to be considered the "root"
directory of terraform.

## How to create a new environment

Recommended: Use nix-shell from the root of this repository to ensure that you
have the right version of terraform.

1. Export "CAILLEACH_DIR" environment variable to a repository where you want to
   store environment specific data.
1. Export "ENV" as the name of the environment
1. Create environment directory.
   ```bash
   export ENV_DIR="$CAILLEACH_DIR/environments/$ENV"
   mkdir -p "$ENV_DIR"
   ```
1. Create backend-config in `"$ENV_DIR/backend.tfvars` which looks like this:
   ```tf
   region  = "<aws-region>"
   bucket  = "<aws-bucket>"
   key = "<s3-backend-key>"
   dynamodb_table = "<dynamodb-lock-table>"
   ```

   Please refer to [s3 backend
   docs](https://www.terraform.io/docs/backends/types/s3.html) for details.
1. Create token from hetzner cloud and put it in a file called
   `$ENV_DIR/hcloud-token.dec`<sup>[1]</sup>.
   ```
   export HCLOUD_TOKEN=<token>
   ```
1. Create ssh key-pair, put the private key in a filed called
   `$ENV_DIR/operator-ssh.dec`<sup>[1]</sup>.
1. Create variables for the environment in `$ENV_DIR/terraform.tfvar`, example:
   ```tf
   environment = <env>
   sft_server_names = ["1", "2"]
   root_domain = "example.com"
   operator_ssh_public_key = <public key from step above>
   ```
1. Initialiaze terraform
   ```
   make init ENV=$ENV
   ```
1. Apply terraform
   ```
   make apply ENV=$ENV
   ```

<sup>[1]</sup>For wire employees: Encrypt this file using `sops`, it will not
work in the `nix-shell`, so change shell as needed.
