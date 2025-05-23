
# Wire-in-a-Box Deployment Guide

This guide provides detailed instructions for deploying Wire-in-a-Box (WIAB) using Ansible on an Ubuntu 24.04 system. The deployment process is structured into multiple blocks within the Ansible playbook, offering flexibility in execution.

Typically, the deployment process runs seamlessly without requiring any external flags. However, if needed, you have the option to skip certain tasks based on their conditional flags. For instance, if you wish to bypass the [Wire Artifact Download tasks](#8-wire-artifact-download) —which can be time-consuming—you can manage the artifacts independently and skip this step in the Ansible workflow by using the flag `-e skip_download=true`.

For more detailed instructions on each task, please refer to the [Deployment Flow section](#deployment-flow).

## Requirements

- **System**: Ubuntu 24.04 (Focal) on amd64 architecture with following requirements
  - CPU cores >= 16
  - Memory > 16 GiB
  - Disk > 200 GiB 
- **Network**: No interference from UFW or other system specific firewalls, and IP forwarding enabled between network cards. Public internet access to download Wire artifacts and Ubuntu packages.
- **Packages**: Ansible and Git installed on the localhost
  - Ansible version: [core 2.16.3] or compatible
- **Permissions**: Sudo access required for installation on remote_node
- **Deployment requirements**: Edit the file [host.yml](../ansible/inventory/demo/host.yml) (post cloning) to update and verify the following default variables:
    - ansible_host: deploy_node IP address or hostname (Mandatory)
    - ansible_user: deploy_node username (Mandatory)
    - ansible_ssh_private_key_file: SSH key file path for username@deploy_node (Mandatory)
    - target_domain: The domain you want to use for wire installation (Mandatory)
    - wire_ip: Wire Access IP, could be same as ansible_host but IP (Optional). If not specified, can be calculated automatically, given below network ACLs are in place.
    - artifact_hash: Check with wire support about this value.
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
ansible-playbook -i ansible/inventory/demo/host.yml ansible/wiab-demo/deploy_wiab.yml
```

## Deployment Flow

The deployment process follows these steps as defined in the main playbook:

### 1. DNS Verification

The playbook starts by verifying DNS records to ensure proper name resolution:
- Imports [verify_dns.yml](../ansible/wiab-demo/verify_dns.yml)
- Can be skipped by setting `skip_verify_dns=true`
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
- Can be skipped by setting `skip_install_pkgs=true`

### 5. SSH Key Management

- Imports [setup_ssh.yml](../ansible/wiab-demo/setup_ssh.yml) to manage SSH keys for Minikube nodes and SSH proxying for the deploy_node and minikube nodes
- Runs if any of the following tasks are enabled:
  - Minikube setup
  - Asset host setup
  - Offline seed setup

### 6. Minikube Cluster Configuration

- Imports [minikube_cluster.yml](../ansible/wiab-demo/minikube_cluster.yml) to set up a Kubernetes cluster using Minikube
- All minikube configurable parameters are available in [host.yml](../ansible/inventory/demo/host.yml)
- Can be skipped with `skip_minikube=true`

### 7. IPTables Rules

- Imports [iptables_rules.yml](../ansible/wiab-demo/iptables_rules.yml) to configure network rules on deploy_node
- It will configure network forwarding and postrouting rules to route traffic to k8s nodes
- Only runs if Minikube setup isn't skipped, it depends on IP address of k8s nodes from Minikube

### 8. Wire Artifact Download

- Imports [download_artifact.yml](../ansible/wiab-demo/download_artifact.yml) to fetch the Wire components
- It is required to download all the artifacts required for further installation
- Can be skipped with `skip_download=true`

### 9. Minikube Node Inventory Setup

The playbook then configures access to the Kubernetes nodes:
- Retrieves the host IP (asset_host) on the Minikube network and Ip addresses for minikube k8s nodes
- Sets up SSH proxy access to cluster nodes by:
  - Creating a temporary directory for SSH keys on the localhost
  - Writing the private key to a file in the temporary directory
  - Adding the above calculated hosts to the Ansible inventory with appropriate SSH settings

### 10. Asset Host Setup

- Imports [setup-offline-sources.yml](../ansible/setup-offline-sources.yml) to configure the asset host
- It will offer wire deployment artifacts as service for further installation
- Can be skipped with `skip_asset_host=true`

### 11. Container Seeding

- Imports [seed-offline-containerd.yml](../ansible/seed-offline-containerd.yml) to seed containers in K8s cluster nodes
- It will seed the docker images shipped for the wire related helm charts in the minikube k8s nodes
- Can be skipped with `skip_setup_offline_seed=true`

### 12. Wire Secrets Creation

- Imports [wire_secrets.yml](../ansible/wiab-demo/wire_secrets.yml) to create required secrets for wire helm charts
- Only runs if both `skip_wire_secrets` and `skip_helm_install` are false

### 13. Helm Chart Installation

- Imports [helm_install.yml](../ansible/wiab-demo/helm_install.yml) to deploy Wire components using Helm
- These charts can be configured in [host.yml](../ansible/inventory/demo/host.yml)
- Can be skipped with `skip_helm_install=true`

### 14. Temporary Cleanup

- Locates all temporary SSH key directories created during deployment
- Lists and removes these directories

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
- All the iptables rules are not persisted after reboots, but they can be regenerated by running the entire pipeline. Optionally, we can skip everything else.
```
ansible-playbook -i ansible/inventory/demo/host.yml ansible/wiab-demo/deploy_wiab.yml -e skip_setup_offline_seed=true -e skip_wire_secrets=true -e skip_asset_host=true -e skip_download=true -e skip_install_pkgs=true
```
- The playbook is designed to be idempotent, with skip flags for each major section
- Temporary SSH keys are created and cleaned up automatically
- The deployment creates a single-node Kubernetes cluster with all Wire services

## Cleaning/Uninstalling Wire-in-a-Box

The deployment includes a cleanup playbook that can be used to remove all components:

```bash
ansible-playbook -i ansible/inventory/demo/host.yml ansible/wiab-demo/clean_wiab.yml -e "remove_minikube=true uninstall_pkgs=true remove_iptables=true remove_ssh=true remove_artifacts=true clean_assethost=true"
```

The cleanup process handles:
- **Minikube**: Stops and deletes the Kubernetes cluster (optional `remove_minikube=true`)
- **Packages**: Removes installed dependencies including Docker, kubectl, yq, etc. (optional `uninstall_pkgs=true`)
- **IPTables**: Restores pre-installation network rules (optional `remove_iptables=true`)
- **SSH Keys**: Removes generated SSH keys (optional `remove_ssh=true`)
- **Artifacts**: Deletes downloaded deployment artifacts (optional `remove_artifacts=true`)
- **Asset Host**: Stops the asset hosting service and cleans up related files (optional `clean_assethost=true`)

Each cleanup operation can be enabled/disabled independently with the corresponding variables.
