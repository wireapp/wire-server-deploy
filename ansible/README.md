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

Assuming blue servers are serving version 42 and we want to upgrade to version 43.

In this case the initial group vars for the `sft_servers_blue` group would look
like this:
```yaml
sft_servers_blue:
  vars:
    sft_artifact_file_url: "https://example.com/path/to/sftd_42.tar.gz"
    sft_artifact_checksum: somechecksum_42
    srv_announcer_active: true
```

For `sft_servers_green`, `srv_announcer_active` must be `false`.

1. Make sure all env variables like `ENV`, `ENV_DIR` are set.
1. Create terraform inventory (This section assumes all commands are executed
   from the root of this repository)
   ```bash
   make -C terraform/environment create-inventory
   ```
1. Setup green servers to have version 43 and become active:
   ```yaml
   sft_servers_green:
   vars:
     sft_artifact_file_url: "https://example.com/path/to/sftd_43.tar.gz"
     sft_artifact_checksum: somechecksum_43
     srv_announcer_active: true
   ```
1. Run ansible
   ```yaml
   make -C ansible provision-sft
   ```

   This will make sure that green SFT servers will have version 43 of sftd and
   they are available. At this point we will have both blue green servers as
   active.
1. Ensure that new servers function properly. If they don't you can set
   `srv_announcer_active` to `false` for the green group.
1. If the servers are working properly, setup the old servers to be deactivated:
   ```yaml
   sft_servers_blue:
   vars:
     sft_artifact_file_url: "https://example.com/path/to/sftd_42.tar.gz"
     sft_artifact_checksum: somechecksum_42
     srv_announcer_active: false
   ```
1. Run ansible again
   ```yaml
   make -C ansible provision-sft
   ```
1. There is a race condition in stopping SRV announcers, which will mean that
   sometimes a server will not get removed from the list. This can be found by
   running this command:
   ```bash
   dig SRV _sft._tcp.<env>.<domain>
   ```
   
   If an old server is found even after TTL for the record has expired, it must
   be taken care of manually. It is safe to delete all the SRV records, they
   should get re-populated within 20 seconds.

### Decomission one specific server

Assuming the terraform variables look like this and we have to take down server
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
   sft_server_names_blue: ["2", 5"]
   ```
1. Run terraform (this will again wait for approval)
   ```bash
   make -C terraform/environment apply
   ```

#### When the server is not active

1. Remove the server from `sft_server_names_blue` and add a new name by
   replacing the first line like this:
   ```tfvars
   sft_server_names_blue: ["2", 5"]
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
1. We want to make all th servers "cx31".
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
