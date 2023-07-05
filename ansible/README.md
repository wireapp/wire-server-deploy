# Ansible-based deployment

In a production environment, some parts of the wire-server infrastructure (such as e.g. cassandra databases) are best configured outside kubernetes. Additionally, kubernetes can be rapidly set up with a project called kubespray, via ansible.

This directory hosts a range of ansible playbooks to install kubernetes and databases necessary for wire-server. For documentation on usage, please refer to the [Administrator's Guide](https://docs.wire.com), notably the production installation.


## Bootstrap environment created by `terraform/environment`

An 'environment' is supposed to represent all the setup required for the Wire
backend to function.

'Bootstrapping' an environment means running a range of idempotent ansible
playbooks against servers specified in an inventory, resulting in a fully
functional environment. This action can be re-run as often as you want (e.g. in
case you change some variables or upgrade to new versions).

At the moment, the environment can have SFT servers as well as machines on which
Kubernetes can be deployed on; more will be added.

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

## Bootstrap a Kubernetes cluster with Kubespray

* while necessary Inventory hosts & groups are being defined/generated with Terraform
  (see `terraform/environment/kubernetes.inventory.tf`), Kubespray Inventory variables
  are supposed to be defined in `${ENV_DIR}/inventory/inventory.yml`
* after bootstrapping Kubernetes, a plain-text version of the kubeconfig file should 
  exist under `$ENV_DIR/kubeconfig.dec`<sup>[1]</sup>

<sup>[1]</sup>For wire employees: Encrypt this file using the `sops` toolchain in
*cailleach*.

## Operating SFT Servers

There are a few things to consider while running SFT servers.

1. Restarting SFT servers while a call is going on will drop the call. To avoid
   this, we must provide 6 hours of grace period after stopping SRV record
   announcements.
1. Let's encrypt will not issue more than 50 certificates per registered domain
   per week.
1. Let's encrypt will not do more than 5 renewals per set of domains.

To deal with these issues, we create 2 groups (blue and green) of the SFT
servers. These groups are configured like this in terraform:
```tfvars
sft_server_names_blue = ["1", "2"] # defaults to []
sft_server_type_blue = "cx21" # defaults to "cx11"
sft_server_names_green = ["3", "4"] # defaults to []
sft_server_type_green = "cx21" # defaults to "cx11"
```

Terraform will put all the SFT servers (blue and green) in a group called
`sft_servers` and additionally, it will put the blue servers in
`sft_servers_blue` group and green servers in `sft_servers_green` group. This
allows putting common variables in the `sft_servers` group and uncommon ones
(like `sft_artifact_file_url`) in the respective groups.

To maintain uptime, at least one of the groups should be active. The size of the
groups should ideally be equal and one group must be able to support peak
traffic.

### Deployment

Assuming blue servers are serving version 42, green servers are serving version 43 and we want to upgrade to version 44.

Note: The releases/artifacts for SFT can be found at: https://github.com/wearezeta/avs-service/releases

We are going to be working on the `group_vars` files in the cailleach (https://github.com/zinfra/cailleach) repository, located under `environments/prod/inventory/group_vars/`

In this case the initial group vars for the `sft_servers_blue` group would look
like this:

```yaml
sft_servers_blue:
  vars:
    sft_artifact_file_url: "https://default.domain/path/to/sftd_42.tar.gz"
    sft_artifact_checksum: somechecksum_42
    srv_announcer_active: true
```

For `sft_servers_green`, `srv_announcer_active` must be `false`.

1. Make sure all env variables like `ENV`, `ENV_DIR` are set. Here we are working on the `prod` environment, so we do `ENV='prod'`
2. Create terraform inventory (This section assumes all commands are executed
   from the root of this repository)
   ```bash
   make -C terraform/environment create-inventory
   ```
3. Setup green servers to have version 44 and become active:
   ```yaml
   sft_servers_green:
   vars:
     sft_artifact_file_url: "https://default.domain/path/to/sftd_44.tar.gz"
     sft_artifact_checksum: somechecksum_44
     srv_announcer_active: true
   ```
4. At this point, you should create a Pull Request for the changes, and have it merged with `cailleach` once approved by the team.
   The CI will now run ansible automatically, and the changes will take effect. The following lines are for reference only, and represent what the CI does, and what used to be done by hand at this point:

   Run ansible in Wire Server Deploy
   ```yaml
   make -C ansible provision-sft
   ```

   This will make sure that green SFT servers will have version 43 of sftd and
   they are available. At this point we will have both blue green servers as
   active.
5. Ensure that new servers function properly. If they don't you can set
   `srv_announcer_active` to `false` for the green group, and make a PR against `cailleach`.
6. If the servers are working properly, setup the old servers to be deactivated:
   ```yaml
   sft_servers_blue:
   vars:
     sft_artifact_file_url: "https://default.domain/path/to/sftd_42.tar.gz"
     sft_artifact_checksum: somechecksum_42
     srv_announcer_active: false
   ```
7. At this point again, you should make and merge a Pull Request against `cailleach` with these changes, the following line represents what CI then does, and used to be done by hand:
   Run ansible again
   ```yaml
   make -C ansible provision-sft
   ```
7. There is a race condition in stopping SRV announcers, which will mean that
   sometimes a server will not get removed from the list. This can be found by
   running this command:
   ```bash
   dig SRV _sft._tcp.<env>.<domain>
   ```

   If an old server is found even after TTL for the record has expired, it must
   be taken care of manually. It is safe to delete all the SRV records, they
   should get re-populated within 20 seconds.

### Decommission one specific server

Assuming the Terraform variables look like this and we have to take down server
`"1"`.
```tfvars
sft_server_names_blue = ["1", "2"] # defaults to []
sft_server_type_blue = "cx21" # defaults to "cx11"
sft_server_names_green = ["3", "4"] # defaults to []
sft_server_type_green = "cx21" # defaults to "cx11"
environment = "staging"
```

#### When the server is active

1. Add one more server to the blue group by replacing the first line with:
   ```tfvars
   sft_server_names_blue = ["1", "2", "5"] # These shouldn't overlap with the green ones
   ```
1. Run terraform (this will wait for approval)
   ```bash
   make -C terraform/environment init apply create-inventory
   ```
1. Set `srv_announcer_active` to `false` only for the host which is to be taken
   down. Here the ansible host name would be `staging-sft-1`
1. Run ansible
   ```bash
   make -C ansible provision-sft
   ```
1. Ensure that the SRV records don't contain `sft1`, same as last step of deployment procedure.
1. Monitor `sft_calls` metric to make sure that there are no calls left.
1. Setup instance for deletion by removing it from `sft_server_names_blue`:
   ```tfvars
   sft_server_names_blue: ["2", "5"]
   ```
1. Run terraform (this will again wait for approval)
   ```bash
   make -C terraform/environment apply
   ```

#### When the server is not active

1. Remove the server from `sft_server_names_blue` and add a new name by
   replacing the first line like this:
   ```tfvars
   sft_server_names_blue: ["2", "5"]
   ```
1. Run terraform (this will wait for approval)
   ```bash
   make -C terraform/environment init apply
   ```

### Change server type of all servers

Assuming:
1. Initial tfvars has these variables:
   ```
   sft_server_names_blue = ["1", "2"] # defaults to []
   sft_server_type_blue = "cx21" # defaults to "cx11"
   sft_server_names_green = ["3", "4"] # defaults to []
   sft_server_type_green = "cx21" # defaults to "cx11"
   environment = "staging"
   ```
1. We want to make all the servers "cx31".
1. The blue group is active, green is not.

We can do it like this:

1. Replace all the green servers by changing `server_type`:
   ```
   sft_server_type_green = "cx31"
   ```
1. Run terraform (will wait for approval)
   ```
   make -C terraform/environment init apply create-inventory
   ```
1. Deploy the same version as blue to green by following steps in the deployment
   procedure.
1. Once the blue servers are inactive and all the calls have finished, replace
   them the same way as green servers. No need to make them active again.
