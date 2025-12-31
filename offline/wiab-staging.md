# Scope

**Wire in a Box (WIAB) Staging** is a demo installation of Wire running on a single physical machine using KVM-based virtual machines. This setup replicates the multi-node production Wire architecture in a consolidated environment suitable for testing, evaluation, and learning about Wire's infrastructure—but **not for production use**.

**Important:** This is a sandbox environment. Data from a staging installation cannot be migrated to production. WIAB Staging is designed for experimentation, validation, and understanding Wire's deployment model.

## Requirements

**Architecture Overview:**
- Multiple VMs (7) are deployed to simulate production infrastructure with separate roles (Kubernetes, data services, asset storage)
- All VMs share the same physical node and storage, creating a single failure domain
- [Calling services](https://docs.wire.com/latest/understand/overview.html#calling) will share the same k8s cluster as Wire services hence, all infrastructure will be DMZ (De-militarized zone).
- This solution helps developers understand Wire's infrastructure requirements and test deployment processes

**Resource Requirements:**
- One physical machine with hypervisor support:
  - **Memory:** 61 GiB RAM
  - **Compute:** 29 vCPUs  
  - **Storage:** 550 GB disk space (thin-provisioned)
  - 7 VMs with [Ubuntu 22](https://releases.ubuntu.com/jammy/) as per (#VM-Provisioning)
- **DNS Records**: 
    - a way to create DNS records for your domain name (e.g. wire.example.com) 
    - Find a detailed explanation at [How to set up DNS records](https://docs.wire.com/latest/how-to/install/demo-wiab.html#dns-requirements)
- **SSL/TLS certificates**:
    - a way to create SSL/TLS certificates for your domain name (to allow connecting via https://)
    - To ease out the process of managing certs, we recommend using [Let's Encrypt](https://letsencrypt.org/getting-started/) & [cert-manager](https://cert-manager.io/docs/tutorials/acme/http-validation/)
- **Network**: No interference from UFW or other system specific firewalls, and IP forwarding enabled between network cards. An IP address reachable for ssh and which can act as entry point for Wire traffic.
- **Wire-server-deploy artifact**: A tar bundle containing all the required bash scripts, deb packages, ansible playbooks, helm charts and docker images to help with the installation. Reach out to [Wire support](https://support.wire.com/) to get access to the latest stable Wire artifact.

## VM Provisioning

We would require 7 VMs as per the following details, you can choose to use your own hypervisor to manage the VMs or use our [Wiab staging ansible playbook](https://github.com/wireapp/wire-server-deploy/blob/master/ansible/wiab-staging-provision.yml) against your physical node to setup the VMs.

**VM Architecture and Resource Allocation:**

| Hostname | Role | RAM | vCPUs | Disk |
|----------|------|-----|-------|------|
| assethost | Asset/Storage Server | 4 GiB | 2 | 100 GB |
| kubenode1 | Kubernetes Node 1 | 7 GiB | 5 | 50 GB |
| kubenode2 | Kubernetes Node 2 | 7 GiB | 5 | 50 GB |
| kubenode3 | Kubernetes Node 3 | 7 GiB | 5 | 50 GB |
| datanode1 | Data Node 1 | 12 GiB | 4 | 100 GB |
| datanode2 | Data Node 2 | 12 GiB | 4 | 100 GB |
| datanode3 | Data Node 3 | 12 GiB | 4 | 100 GB |
| **Total** | | **61 GiB** | **29** | **550 GB** |

*Note: These specifications are optimized for testing and validation purposes, not for performance benchmarking.*

**VM Service Distribution:**

- **kubenodes (kubenode1, kubenode2, kubenode3):** Run the Kubernetes cluster and host Wire backend services
- **datanodes (datanode1, datanode2, datanode3):** Run distributed data services:
  - Cassandra (distributed database)
  - PostgreSQL (operational database)
  - Elasticsearch (search engine)
  - Minio (S3-compatible object storage)
  - RabbitMQ (message broker)
- **assethost:** Hosts static assets to be used by kubenodes and datanodes

## WIAB staging ansible playbook

The ansible playbook will perform the following operations for you:

**System Setup & Networking**:
  - Updates all system packages and installs required tools (git, curl, docker, qemu, libvirt, yq, etc.)
  - Configures SSH, firewall (nftables), and user permissions (sudo, kvm, docker groups)

**wire-server-deploy Artifact & Ubuntu Cloud Image**:
  - Downloads wire-server-deploy static artifact and Ubuntu cloud image
  - Extracts artifacts and sets proper file permissions
  - *Note: The wire-server-deploy artifact downloaded corresponds to the currently supported version*

**Libvirt Network Setup and VM Creation**:
  - Removes default libvirt network and creates custom "wirebox" network
  - Launches VMs using the `offline-vm-setup.sh` script with KVM
  - Creates an SSH key directory at `/home/ansible_user/wire-server-deploy/ssh` for VM access

**Ansible Inventory Generation**:
  - Generates inventory.yml with actual VM IPs replacing placeholders
  - Configures network interface variables for all k8s-nodes and datanodes


*Note: Skip the Ansible playbook step if you are managing VMs with your own hypervisor.* 

### Getting started with Ansible playbook

**Step 1: Obtain the ansible directory**

We need the whole ansible directory as ansible-playbook uses some templates for its operations. Choose one method to download the `wire-server-deploy/ansible` directory:

**Option A: Download as ZIP**
```bash
wget https://github.com/wireapp/wire-server-deploy/archive/refs/heads/master.zip
unzip master.zip
cd wire-server-deploy-master
```

**Option B: Clone with Git**
```bash
git clone https://github.com/wireapp/wire-server-deploy.git
cd wire-server-deploy
```

**Step 2: Configure your Ansible inventory for your physical machine**

A sample inventory is available at [ansible/inventory/demo/wiab-staging.yml](https://github.com/wireapp/wire-server-deploy/blob/master/ansible/inventory/demo/wiab-staging.yml).

*Note: Replace example.com with your physical machine address where KVM is available and adjust other variables accordingly.* 

**Step 3: Run the VM and network provision**

```bash
ansible-playbook -i ansible/inventory/demo/wiab-staging.yml ansible/wiab-staging-provision.yml
```

*Note: Ansible core version 2.16.3 or compatible is required for this step*

## Ensure secondary ansible inventory for VMs

Now you should have 7 VMs running on your physical machine. If you have used the ansible playbook, you should also have a directory `/home/ansible_user/wire-server-deploy` with all resources required for further deployment. If you didn't use the above playbook, download the `wire-server-deploy` artifact shared by Wire support and unarchieve (tar tgz) it.

Ensure the inventory file `ansible/inventory/offline/inventory.yml` in the directory `/home/ansible_user/wire-server-deploy` contains values corresponding to your VMs. If you have already used the [Ansible playbook above](#getting-started-with-ansible-playbook) to set up VMs, this file should have been prepared for you.

## Next steps

Since the inventory is ready, please continue with the following steps:

### Environment Setup

- **[Making tooling available in your environment](docs_ubuntu_22.04.md#making-tooling-available-in-your-environment)**
  - Source the `bin/offline-env.sh` shell script to set up a `d` alias that runs commands inside a Docker container with all necessary tools for offline deployment.

- **[Generating secrets](docs_ubuntu_22.04.md#generating-secrets)**
  - Run `./bin/offline-secrets.sh` to generate fresh secrets for Minio and coturn services. This creates two secret files: `ansible/inventory/group_vars/all/secrets.yaml` and `values/wire-server/secrets.yaml`.

### Kubernetes & Data Services Deployment

- **[Deploying Kubernetes and stateful services](docs_ubuntu_22.04.md#deploying-kubernetes-and-stateful-services)**
  - Run `d ./bin/offline-cluster.sh` to deploy Kubernetes and stateful services (Cassandra, PostgreSQL, Elasticsearch, Minio, RabbitMQ). This script deploys all infrastructure needed for Wire backend operations.

### Wire Components Deployment

- **Deploying Helm charts**
  - **[Deploying stateless services and other dependencies](docs_ubuntu_22.04.md#deploying-stateless-dependencies)**
    - Deploy cassandra-external, elasticsearch-external, minio-external, and databases-ephemeral helm charts to set up connections to external data services and stateless database dependencies.
  
  - **[Deploying Wire Server](docs_ubuntu_22.04.md#deploying-wire-server)**
    - Install the core Wire backend platform with `d helm install wire-server ./charts/wire-server`. Update `values/wire-server/values.yaml` with your domain and inspect `values/wire-server/secrets.yaml` for required secrets.
  
  - **[Deploying webapp](docs_ubuntu_22.04.md#deploying-webapp)**
    - Deploy the Wire web application frontend. Set your domain name and configure it for user access to the Wire interface.
  
  - **[Deploying team-settings](docs_ubuntu_22.04.md#deploying-team-settings)**
    - Install team management and settings services for enterprise features and team administration.
  
  - **[Deploying account-pages](docs_ubuntu_22.04.md#deploying-account-pages)**
    - Deploy account management pages for user profile, password reset, and account-related functionalities.
  
  - **[Deploying smallstep-accomp](docs_ubuntu_22.04.md#deploying-smallstep-accomp)**
    - Install the smallstep ACME companion for certificate management integration.

### Network & Security

- **[Enabling emails for wire](smtp.md)**
  - Configure SMTP for user onboarding via email. Deploy either a temporary SMTP service included in the bundle or integrate with your existing SMTP relay, and ensure proper network configuration for email delivery.

- **[Deploy ingress-nginx-controller](docs_ubuntu_22.04.md#deploy-ingress-nginx-controller)**
  - Install nginx ingress controller as the entry point for HTTP/HTTPS traffic routing to Wire services. This component is required for all traffic forwarding methods.

- **[Acquiring / Deploying SSL Certificates](docs_ubuntu_22.04.md#acquiring--deploying-ssl-certificates)**
  - Configure SSL/TLS certificates either by bringing your own or using cert-manager with Let's Encrypt. SSL certificates are required by the nginx-ingress-services helm chart for secure HTTPS connections.

### Calling Services

- **[Installing SFTD](docs_ubuntu_22.04.md#installing-sftd)**
  - Deploy the Selective Forwarding Unit (SFT) calling server for Wire's voice and video calling capabilities. Optionally enable cooperation with TURN servers and configure appropriate node annotations for external IPs.

- **[Installing Coturn](coturn.md)**
  - Deploy TURN/STUN servers for WebRTC connectivity, enabling peer-to-peer communication for calling services and ensuring connectivity through firewalls and NATs.

## Network Traffic Configuration

### Bring traffic from Physical machine to Wire services in k8s cluster

If you used the Ansible playbook earlier, nftables firewall rules are pre-configured to forward traffic. If you set up VMs manually with your own hypervisor, you must manually configure network traffic flow using nftables.

**Required Network Configuration:**

The physical machine must forward traffic from external clients to the Kubernetes cluster running Wire services. This involves:

1. **HTTP/HTTPS Traffic (Ingress)** - Forward ports 80 and 443 to the nginx-ingress-controller running on a Kubernetes node
   - Port 80 (HTTP) → Kubernetes node port 31772
   - Port 443 (HTTPS) → Kubernetes node port 31773

2. **Calling Services Traffic (Coturn/SFT)** - Forward media and TURN protocol traffic to Coturn/SFT
   - Port 3478 (TCP/UDP) → Coturn control traffic
   - Ports 32768-65535 (UDP) → Media relay traffic for WebRTC calling

**Implementation:**

Follow the detailed nftables configuration instructions in [Configure the port redirection in Nftables](coturn.md#configure-the-port-redirection-in-nftables). The guide covers:
- Defining your network variables (Coturn IP, Kubernetes node IP, WAN interface)
- Creating NAT rules for HTTP/HTTPS ingress traffic
- Setting up TURN protocol forwarding for Coturn
- Restarting nftables to apply changes
