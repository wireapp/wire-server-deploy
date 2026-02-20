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
  - **Memory:** 55 GiB RAM
  - **Compute:** 29 vCPUs  
  - **Storage:** 850 GB disk space (thin-provisioned)
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
| kubenode1 | Kubernetes Node 1 | 9 GiB | 5 | 150 GB |
| kubenode2 | Kubernetes Node 2 | 9 GiB | 5 | 150 GB |
| kubenode3 | Kubernetes Node 3 | 9 GiB | 5 | 150 GB |
| datanode1 | Data Node 1 | 8 GiB | 4 | 100 GB |
| datanode2 | Data Node 2 | 8 GiB | 4 | 100 GB |
| datanode3 | Data Node 3 | 8 GiB | 4 | 100 GB |
| **Total** | | **55 GiB** | **29** | **850 GB** |

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

### Helm Operations to install wire services and supporting helm charts

**Helm chart deployment (automated):** The script `bin/helm-operations.sh` will deploy the charts for you. It prepares `values.yaml`/`secrets.yaml`, customizes them for your domain/IPs, then runs Helm installs/upgrades in the correct order.

**User-provided inputs (set these before running):**
- `TARGET_SYSTEM`: your domain (e.g., `wire.example.com` or `example.dev`).
- `CERT_MASTER_EMAIL`: email used by cert-manager for ACME registration.
- `HOST_IP`: public IP that matches your DNS A record (auto-detected if empty).

**Charts deployed by the script:**
- External datastores and helpers: `cassandra-external`, `elasticsearch-external`, `minio-external`, `rabbitmq-external`, `databases-ephemeral`, `reaper`, `fake-aws`, `demo-smtp`.
- Wire services: `wire-server`, `webapp`, `account-pages`, `team-settings`, `smallstep-accomp`.
- Ingress and certificates: `ingress-nginx-controller`, `cert-manager`, `nginx-ingress-services`.
- Calling services: `sftd`, `coturn`.

**Values and secrets generation:**
- Creates `values.yaml` and `secrets.yaml` from `prod-values.example.yaml` and `prod-secrets.example.yaml` for each chart under `values/`.
- Backs up any existing `values.yaml`/`secrets.yaml` before replacing them.

**Values configured by the script:**
- Replaces `example.com` with `TARGET_SYSTEM` in Wire and webapp hostnames.
- Enables cert-manager and sets `certmasterEmail` using `CERT_MASTER_EMAIL`.
- Sets SFTD hosts and switches issuer to `letsencrypt-http01`.
- Sets coturn listen/relay/external IPs using the calling node IP and `HOST_IP`.

*Note: The `bin/helm-operations.sh` script above deploys these charts; you do not need to run the Helm commands manually unless you want to customize or debug.*

## Network Traffic Configuration

### Bring traffic from the physical machine to Wire services in the k8s cluster

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

Use the detailed nftables rules in [../ansible/files/wiab_server_nftables.conf.j2](../ansible/files/wiab_server_nftables.conf.j2) as the template. The guide covers:
- Defining your network variables (Coturn IP, Kubernetes node IP, WAN interface)
- Creating NAT rules for HTTP/HTTPS ingress traffic
- Setting up TURN protocol forwarding for Coturn
- Restarting nftables to apply changes

You can also apply these rules using the Ansible playbook, by following:

```bash
ansible-playbook -i inventory.yml ansible/wiab-staging-nftables.yml
```

*Note: If you ran the playbook wiab-staging-provision.yml then it might already be configured for you. Please confirm before running.*

The inventory should define the following variables:

```ini
[all:vars]
# Kubernetes node IPs
kubenode1_ip=192.168.122.11
kubenode2_ip=192.168.122.12
kubenode3_ip=192.168.122.13

# Calling services node (usually kubenode3)
calling_node_ip=192.168.122.13

# Host WAN interface name
inf_wan=eth0
```

> **Note (cert-manager & hairpin NAT):**
> When cert-manager performs HTTP-01 self-checks inside the cluster, traffic can hairpin (Pod → Node → host public IP → DNAT → Node → Ingress).
> If your nftables rules DNAT in `PREROUTING` without a matching SNAT on `virbr0 → virbr0`, return packets may bypass the host and break conntrack, causing HTTP-01 timeouts, resulting in certificate verification failure.
> Additionally, strict `rp_filter` can drop asymmetric return packets.
> If cert-manager is deployed in a NAT/bridge (`virbr0`) environment, first verify whether certificate issuance is failing before applying hairpin handling.
> Check whether certificates are successfully issued:
> ```bash
> d kubectl get certificates
> ```
> If certificates are not in `Ready=True` state, inspect cert-manager logs for HTTP-01 self-check or timeout errors:
> ```bash
> d kubectl logs -n cert-manager-ns <cert-manager-pod-id>
> ```
> If you observe HTTP-01 challenge timeouts or self-check failures in a NAT/bridge environment, hairpin SNAT and relaxed reverse-path filtering handling may be required.
  > - Relax reverse-path filtering to loose mode to allow asymmetric flows:
  >   ```bash
  >   sudo sysctl -w net.ipv4.conf.all.rp_filter=2
  >   sudo sysctl -w net.ipv4.conf.virbr0.rp_filter=2
  >   ```
  >   These settings help conntrack reverse DNAT correctly and avoid drops during cert-manager’s HTTP-01 challenges in NAT/bridge (virbr0) environments.
  >
  > - Enable Hairpin SNAT (temporary for cert-manager HTTP-01):
  >   ```bash
  >   sudo nft insert rule ip nat POSTROUTING position 0 \
  >   iifname "virbr0" oifname "virbr0" \
  >   ip daddr 192.168.122.0/24 ct status dnat \
  >   counter masquerade \
  >   comment "wire-hairpin-dnat-virbr0"
  >   ```
  >   This forces DNATed traffic that hairpins over the bridge to be masqueraded, ensuring return traffic flows back through the host and conntrack can correctly reverse the DNAT.
  >   Verify the rule was added:
  >   ```bash
  >   sudo nft list chain ip nat POSTROUTING
  >   ```
  >   You should see a rule similar to:
  >   ```
  >   iifname "virbr0" oifname "virbr0" ip daddr 192.168.122.0/24 ct status dnat counter masquerade # handle <id>
  >   ```
  >
  > - Remove the rule after certificates are issued
  >   ```bash
  >   d kubectl get certificates
  >   ```
  > - Once Let's Encrypt validation completes and certificates are issued, remove the temporary hairpin SNAT rule. Use the following pipeline to locate the rule handle and delete it safely:
  >   ```bash
  >   sudo nft list chain ip nat POSTROUTING | \
  >     grep wire-hairpin-dnat-virbr0 | \
  >     sed -E 's/.*handle ([0-9]+).*/\1/' | \
  >     xargs -r -I {} sudo nft delete rule ip nat POSTROUTING handle {}
  >   ```


## Further Reading

- **[Deploying stateless services and other dependencies](docs_ubuntu_22.04.md#deploying-stateless-dependencies)**: Read more about external datastores and stateless dependencies.
- **[Deploying Wire Server](docs_ubuntu_22.04.md#deploying-wire-server)**: Read more about core Wire backend deployment and required values/secrets.
- **[Deploying webapp](docs_ubuntu_22.04.md#deploying-webapp)**: Read more about webapp deployment and domain configuration.
- **[Deploying team-settings](docs_ubuntu_22.04.md#deploying-team-settings)**: Read more about team settings services.
- **[Deploying account-pages](docs_ubuntu_22.04.md#deploying-account-pages)**: Read more about account management services.
- **[Deploying smallstep-accomp](docs_ubuntu_22.04.md#deploying-smallstep-accomp)**: Read more about the ACME companion.
- **[Enabling emails for wire](smtp.md)**: Read more about SMTP options for onboarding email delivery and relay setup.
- **[Deploy ingress-nginx-controller](docs_ubuntu_22.04.md#deploy-ingress-nginx-controller)**: Read more about ingress configuration and traffic forwarding requirements.
- **[Acquiring / Deploying SSL Certificates](docs_ubuntu_22.04.md#acquiring--deploying-ssl-certificates)**: Read more about TLS options (Bring Your Own or cert-manager) and certificate requirements.
- **[Installing SFTD](docs_ubuntu_22.04.md#installing-sftd)**: Read more about the Selective Forwarding Unit (SFT) and related configuration.
- **[Installing Coturn](coturn.md)**: Read more about TURN/STUN setup for WebRTC connectivity and NAT traversal.
- **[Configure the port redirection in Nftables](coturn.md#configure-the-port-redirection-in-nftables)**: Read more about configuring Nftables rules
