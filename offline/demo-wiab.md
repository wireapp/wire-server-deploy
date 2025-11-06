
# Wire-in-a-Box Deployment Guide

This guide provides detailed instructions for deploying Wire-in-a-Box (WIAB) using Ansible on an Ubuntu 24.04 system. The deployment process is structured into multiple blocks within the Ansible playbook, offering flexibility in execution. It is designed to configure a remote node, such as example.com (referred to as deploy_node), to install Wire with a custom domain, example.com (referred to as target_domain). These variables must be verified in the file [../ansible/inventory/demo/host.yml](../ansible/inventory/demo/host.yml) before running the pipeline.

Typically, the deployment process runs seamlessly without requiring any external flags. However, if needed, you have the option to skip certain tasks based on their tags. For instance, if you wish to bypass the [Wire Artifact Download tasks](#8-wire-artifact-download) —which can be time-consuming—you can manage the artifacts independently and skip this step in the Ansible workflow by using the tag `--skip-tags download`.

For more detailed instructions on each task, please refer to the [Deployment Flow section](#deployment-flow).

## Requirements

- **System**: Ubuntu 24.04 (Focal) on amd64 architecture with following requirements
  - CPU cores >= 16
  - Memory > 16 GiB
  - Disk > 200 GiB 
- **Network**: No interference from UFW or other system specific firewalls, and IP forwarding enabled between network cards. Public internet access to download Wire artifacts and Ubuntu packages.
- **Packages**: Ansible and Git installed on the localhost (any machine you have access to)
  - Ansible version: [core 2.16.3] or compatible
- **Permissions**: Sudo access required for installation on remote_node
- **Deployment requirements**:
  - Clone of [wire-server-repository](https://github.com/wireapp/wire-server-deploy)
  - The inventory file [../ansible/inventory/demo/host.yml](../ansible/inventory/demo/host.yml) (post cloning the previous repo) to update and verify the following default variables (required unless noted optional):
    - ansible_host: aka **deploy_node** i.e. IP address or hostname of VM where Wire will be deployed (Required)
    - ansible_user: username to access the deploy_node (Required)
    - ansible_ssh_private_key_file: SSH key file path for ansible_user@deploy_node (Required)
    - target_domain: The domain you want to use for wire installation eg. example.com (Required)
    - wire_ip: Gateway IP address for Wire, could be same as deploy_node's IP (Optional). If not specified, the playbook will attempt to detect it (network ACLs permitting). If your deploy_node is only reachable on a private network, set this explicitly.
    - artifact_hash: Check with wire support about this value (used by the download step)

Note: the playbook installs a set of system tools during the `install_pkgs` tasks (for example `docker`/`containerd`, `kubectl`, `minikube` when provisioning a cluster, `yq`, `jq`, `ncat`). If you already have these tools on the deploy node you may skip the `install_pkgs` tag when running the playbook.
- **Network Access Requirements**:


| Protocol | Direction | Start Port | End Port | Ether Type | IP Range   | Reason                                      |
|----------|-----------|------------|----------|------------|------------|---------------------------------------------|
| Any      | egress    | Any        | Any      | IPv4       | Any        | Allow all outgoing IPv4 traffic             |
| Any      | egress    | Any        | Any      | IPv6       | Any        | Allow all outgoing IPv6 traffic             |
| tcp      | ingress   | 22         | 22       | IPv4       | 0.0.0.0/0  | Allow SSH access                            |
| tcp      | ingress   | 443        | 443      | IPv4       | 0.0.0.0/0  | Allow HTTPS traffic                         |
| tcp      | ingress   | 80         | 80       | IPv4       | 0.0.0.0/0  | Allow HTTP traffic                          |
| tcp      | ingress   | 3478       | 3478     | IPv4       | 0.0.0.0/0  | Allow alternative STUN/TURN traffic over TCP|
| udp      | ingress   | 3478       | 3478     | IPv4       | Any        | Allow STUN/TURN traffic for Coturn          |
| udp      | ingress   | 49152      | 65535    | IPv4       | 0.0.0.0/0  | Allow calling traffic for Coturn over UDP   |

- Note: If outbound traffic is restricted, [Note on port ranges](https://docs.wire.com/latest/understand/notes/port-ranges.html) should be followed.

## Getting Started

Start by cloning the repository and running the deployment playbook:

```bash
git clone https://github.com/wireapp/wire-server-deploy.git
cd wire-server-deploy
```
**Note:** Edit the file `ansible/inventory/demo/host.yml` as explained in [Requirements](#requirements) before running the next `ansible-playbook` command.

```
ansible-playbook -i ansible/inventory/demo/host.yml ansible/wiab-demo/deploy_wiab.yml
```

## Deployment Flow

The deployment process follows these steps as defined in the main playbook:

### 1. DNS Verification

The playbook starts by verifying DNS records to ensure proper name resolution:
- Imports [verify_dns.yml](../ansible/wiab-demo/verify_dns.yml)
- Can be skipped using `--skip-tags verify_dns`
- Checks for basic DNS record requirements as explained in the document [How to set up DNS records](https://docs.wire.com/latest/how-to/install/helm.html#how-to-set-up-dns-records) .

### 2. Common Setup Tasks

- Installs Netcat (ncat) on the deployment node, required to find a accessible IP address.
- Sets up variables (facts required by ansible) for Kubernetes nodes based on the Minikube profile and number of nodes.
- We are defining the purpose of nodes in the Minikube cluster.

### 3. Network Verification

- Imports [verify_wire_ip.yml](../ansible/wiab-demo/verify_wire_ip.yml)  to check Wire IP access
- This step is crucial for identifying network ingress and cannot be skipped
- If wire_ip is not already specified, we try to save the tasks the wire_ip on the node in a file

### 4. Package Installation

- Imports [install_pkgs.yml](../ansible/wiab-demo/install_pkgs.yml)  to install required dependencies
- Can be skipped using `--skip-tags install_pkgs`

### 5. SSH Key Management

- Imports [setup_ssh.yml](../ansible/wiab-demo/setup_ssh.yml) to manage SSH keys for Minikube nodes and SSH proxying for the deploy_node and minikube nodes
- **Dependency task:** This task has no tag and runs automatically when `minikube`, `asset_host`, or `seed_containers` are selected
- Cannot be run independently or skipped manually - it's controlled entirely by dependent components
- **Smart dependency:** SSH setup runs when any component that needs it is selected, and is automatically skipped when none of those components are running

### 6. Minikube Cluster Configuration

- Imports [minikube_cluster.yml](../ansible/wiab-demo/minikube_cluster.yml) to set up a Kubernetes cluster using Minikube
- All minikube configurable parameters are available in [host.yml](../ansible/inventory/demo/host.yml)
- Can be skipped using `--skip-tags minikube`

### 7. IPTables Rules

- Imports [iptables_rules.yml](../ansible/wiab-demo/iptables_rules.yml) to configure network rules on deploy_node
- It will configure network forwarding and postrouting rules to route traffic to k8s nodes
- Runs automatically when using `--tags minikube`

### 8. Wire Artifact Download

- Imports [download_artifact.yml](../ansible/wiab-demo/download_artifact.yml) to fetch the Wire components
- It is required to download all the artifacts required for further installation
- Can be skipped using `--skip-tags download`

### 9. Minikube Node Inventory Setup

The playbook then configures access to the Kubernetes nodes:
- **Dependency task:** This setup has no tag and runs automatically when `asset_host` or `seed_containers` are selected
- Retrieves the host IP (asset_host) on the Minikube network and Ip addresses for minikube k8s nodes
- Sets up SSH proxy access to cluster nodes by:
  - Creating a temporary directory for SSH keys on the localhost
  - Writing the private key to a file in the temporary directory
  - Adding the above calculated hosts to the Ansible inventory with appropriate SSH settings
- Cannot be run independently or skipped manually - controlled entirely by `asset_host` and `seed_containers` components

### 10. Asset Host Setup

- Imports [setup-offline-sources.yml](../ansible/setup-offline-sources.yml) to configure the asset host
- It will offer wire deployment artifacts as service for further installation
- Can be skipped using `--skip-tags asset_host`

### 11. Container Seeding

- Imports [seed-offline-containerd.yml](../ansible/seed-offline-containerd.yml) to seed containers in K8s cluster nodes
- It will seed the docker images shipped for the wire related helm charts in the minikube k8s nodes
- Can be skipped using `--skip-tags seed_containers`

### 12. Wire helm charts values preparation

- Imports [wire_values.yml](../ansible/wiab-demo/wire_values.yml) to prepare the Helm chart values
- Runs automatically when using `--tags wire_values`
 
 Note: an admin can choose to skip this step if they already have their own values files and wish to avoid overwriting generated values. Provide your values in the expected `values/` paths and run the next playbook with appropriate tags.

### 13. Wire Secrets Creation

- Imports [wire_secrets.yml](../ansible/wiab-demo/wire_secrets.yml) to create required secrets for wire helm charts
- Runs automatically when using `--tags helm_install`

 Note: `wire_secrets` cannot be skipped when performing a fresh `helm_install` because unique credentials are generated for the deployment. The `helm_install` flow expects secrets to exist (the playbook will include the secrets creation when you run the `helm_install` tag).

### 14. Helm Chart Installation

- Imports [helm_install.yml](../ansible/wiab-demo/helm_install.yml) to deploy Wire components using Helm
- These charts can be configured in [host.yml](../ansible/inventory/demo/host.yml)
- Can be skipped using `--skip-tags helm_install`

### 15. Temporary Cleanup

- Locates all temporary SSH key directories created during deployment
- Lists and removes these directories
- Can be skipped using `--skip-tags cleanup`

## SSH Proxy Configuration

The deployment uses an SSH proxy mechanism to access:
1. Kubernetes nodes within the Minikube cluster
2. The asset host for resource distribution

SSH proxying is configured with:
- Dynamic discovery of SSH key paths (uses `ansible_ssh_private_key_file` if defined)
- StrictHostKeyChecking disabled for convenience
- UserKnownHostsFile set to /dev/null to prevent host key verification issues

## Notes

- This deployment is only meant for testing, all the datastores are ephemeral
- **Tag-Based Execution with Dependency Protection:** The playbook uses a hybrid approach where main components have tags for user control, while dependency tasks have no tags and are controlled automatically through `when` conditions. This prevents accidental skipping of critical dependencies while maintaining a clean user interface.
- You can use Ansible tags to control the execution flow of the playbook. You can run specific tasks using `--tags` or skip specific tasks using `--skip-tags` as explained in the [Deployment Flow](#deployment-flow) section. By default, if no tags are specified, all tasks will run in sequence.

  In case of timeouts or any failures, you can skip tasks that have already been completed by using the appropriate tags. For example, if the Wire artifact download task fails due to a timeout or disk space issue, you can skip the earlier tasks and resume from download:
```bash
ansible-playbook -i ansible/inventory/demo/host.yml ansible/wiab-demo/deploy_wiab.yml --skip-tags verify_dns,install_pkgs,minikube
```
  Or if you just want to run the final deployment steps:
```bash
ansible-playbook -i ansible/inventory/demo/host.yml ansible/wiab-demo/deploy_wiab.yml --tags helm_install
```
  This automatically includes wire secrets creation.

- All the iptables rules are not persisted after reboots, but they can be regenerated by running just the minikube setup:
```bash
ansible-playbook -i ansible/inventory/demo/host.yml ansible/wiab-demo/deploy_wiab.yml --tags minikube
```
  This automatically includes SSH setup and IPTables configuration.

- The playbook is designed to be idempotent, with tags for each major section
- Temporary SSH keys are created and cleaned up automatically
- The deployment creates a single-node Kubernetes cluster with all Wire services

## Offline bundle and alternative chart-only deployment

The deployment playbook downloads an offline bundle that contains:

- Helm chart tarballs (the charts used by the deployment)
- Docker/container image archives (used to seed Minikube/node container runtime)
- Helper scripts such as `bin/wiab-demo/offline_deploy_k8s.sh` which are sourced during the playbook

If you already have a working **Kubernetes cluster** and prefer to use it instead of creating local Minikube nodes, you can skip the Minikube and seeding tasks and run only the Helm chart installation (tags `wire_secrets` and `helm_install`). However, the offline bundle is still required to obtain the charts and the image archive(s) so you can either:

1. Extract charts from the bundle and point Helm to the extracted chart directories, and
2. Load container images into your cluster from the image archive.

Typical steps to load images manually (examples — adapt for your runtime):

```bash
# extract the image archive (example filename, check inside the bundle you downloaded)
tar -xf containers-helm.tar -C /tmp/wiab-images

# For Docker (on the machine that will load images into the cluster):
for img in /tmp/wiab-images/*.tar*; do docker load -i "$img"; done

# For containerd (ctr) on a node that uses containerd:
for img in /tmp/wiab-images/*.tar; do sudo ctr -n=k8s.io images import "$img"; done
```

Note: the playbooks `10. Asset Host Setup` and `11. Container Seeding` can perform these image-extraction and loading steps for you: `setup-offline-sources.yml` will unarchive and host the images via a simple HTTP asset host, and `seed-offline-containerd.yml` will pull/load those images into Minikube nodes. Those playbooks are tuned for Minikube but can be adapted to work with your own cluster by creating an appropriate inventory and adjusting paths.

## kubeconfig path used by Helm in this deployment

Helm commands in the playbook are executed inside a helper Docker container and expect the kubeconfig to be mounted at `{{ ansible_user_dir }}/.kube/config` on the deploy node (the playbook mounts this into the container as `/root/.kube/config`). If you are using your own Kubernetes cluster instead of Minikube, ensure that the kubeconfig for your cluster is available at that path on the deploy node before running the `helm_install` step.

Small note on values and secrets
- The playbook generates Helm values and secrets files under `{{ ansible_user_dir }}/wire-server-deploy/values/` (for example `values/wire-server/values.yaml` and `values/wire-server/secrets.yaml`). These files can be edited before running the `helm_install` step if you need to change chart values or secrets.

## Available Tags

The following tags are available for controlling playbook execution:

### Main Component Tags

| Tag | Description | Automatic Dependencies |
|-----|-------------|----------------------|
| `verify_dns` | DNS record verification | None |
| `install_pkgs` | Package installation | None |
| `minikube` | Minikube cluster setup | SSH setup, IPTables rules |
| `download` | Wire artifact download | None |
| `asset_host` | Asset host configuration | SSH setup, Inventory setup |
| `seed_containers` | Container seeding | SSH setup, Inventory setup |
| `helm_install` | Helm chart installation | None |
| `cleanup` | Temporary file cleanup | None |

### Usage Examples

- **Run a complete minikube setup:** `ansible-playbook ... --tags minikube` (automatically includes SSH setup and IPTables)
- **Run only helm installation:** `ansible-playbook ... --tags helm_install` (automatically includes wire secrets)
- **Run asset host setup:** `ansible-playbook ... --tags asset_host` (automatically includes SSH and inventory setup)
- **Skip DNS verification:** `ansible-playbook ... --skip-tags verify_dns`
- **Run everything except download:** `ansible-playbook ... --skip-tags download`
- **Skip minikube but run asset/container operations:** `ansible-playbook ... --skip-tags verify_dns,install_pkgs,minikube,download` (SSH setup and inventory setup still run automatically for asset_host and seed_containers)


## Cleaning/Uninstalling Wire-in-a-Box

The cleanup playbook uses a **safe-by-default** approach with the special `never` tag - **nothing is destroyed unless you explicitly specify tags**. This prevents accidental destruction of your deployment.

⚠️ **Important:** All cleanup tasks are tagged with `never`, which means they will not run unless explicitly requested. Running the cleanup playbook without any tags will do nothing.

### Basic Usage

**No destruction by default:**
```bash
# This does NOTHING - safe by design (all tasks have 'never' tag)
ansible-playbook -i ansible/inventory/demo/host.yml ansible/wiab-demo/clean_cluster.yml
```

**Explicit destruction required:**
```bash
# Remove specific components using tags (overrides 'never' tag)
ansible-playbook -i ansible/inventory/demo/host.yml ansible/wiab-demo/clean_cluster.yml --tags remove_minikube,remove_artifacts
```

### Available Cleanup Tags

| Tag | Description | What Gets Destroyed |
|-----|-------------|-------------------|
| `remove_minikube` | Stops and deletes the Kubernetes cluster | Minikube cluster, all pods, services, data |
| `remove_packages` | Removes installed packages | Docker, kubectl, yq, ncat, minikube binary |
| `remove_iptables` | Restores pre-installation network rules | All Wire-related network forwarding rules |
| `remove_ssh` | Removes generated SSH keys | Wire-specific SSH keys from deploy node |
| `remove_artifacts` | Deletes downloaded deployment files | Wire artifacts, tarballs, temporary files |
| `clean_assethost` | Stops asset hosting service | Asset hosting service and related files |

### Common Cleanup Scenarios

**Quick cleanup after testing:**
```bash
# Remove cluster and artifacts but keep packages for next deployment
ansible-playbook -i ansible/inventory/demo/host.yml ansible/wiab-demo/clean_cluster.yml --tags remove_minikube,remove_artifacts
```

**Complete cleanup:**
```bash
# Remove everything (use with caution!)
ansible-playbook -i ansible/inventory/demo/host.yml ansible/wiab-demo/clean_cluster.yml --tags remove_minikube,remove_packages,remove_iptables,remove_ssh,remove_artifacts,clean_assethost
```

**Network cleanup only:**
```bash
# Just restore network rules (useful after network issues)
ansible-playbook -i ansible/inventory/demo/host.yml ansible/wiab-demo/clean_cluster.yml --tags remove_iptables
```

**Development workflow:**
```bash
# Reset deployment but keep packages and SSH keys
ansible-playbook -i ansible/inventory/demo/host.yml ansible/wiab-demo/clean_cluster.yml --tags remove_minikube,remove_artifacts,clean_assethost
```

**Package cleanup:**
```bash
# Remove installed packages (be careful - may affect other applications)
ansible-playbook -i ansible/inventory/demo/host.yml ansible/wiab-demo/clean_cluster.yml --tags remove_packages
```

### Safety Features

- **Nothing runs by default:** The playbook requires explicit tags to perform any destruction
- **Granular control:** You choose exactly what to destroy

⚠️ **Warning:** Package removal (`remove_packages`) may affect other applications on the server. Use with caution in shared environments.
