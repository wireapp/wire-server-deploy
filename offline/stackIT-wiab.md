# StackIT Deployment and Configuration Guide

This guide outlines the steps to set up and deploy Wire in a StackIT environment, including DNS configuration, Minikube cluster creation, Docker container setup, and Helm chart deployment. Each task and its associated commands are provided for clarity and customization.

---

## Prerequisites

- ansible
- ssh, ssh key for the ansible user on StackIT VM
- stackIT VM with the following requirements:
  - CPU cores >= 32
  - Memory > 64 GiB
  - Disk > 500 GiB (storage_premium_perf12 - recomended)
  - OS - Ubuntu 24.04
  - Security group with the following rules:

| Protocol | Direction | Start Port | End Port | Ether Type | IP Range   | Reason                                      |
|----------|-----------|------------|----------|------------|------------|---------------------------------------------|
| Any      | egress    | Any        | Any      | IPv4       | Any        | Allow all outgoing IPv4 traffic             |
| Any      | egress    | Any        | Any      | IPv6       | Any        | Allow all outgoing IPv6 traffic             |
| tcp      | ingress   | 22         | 22       | IPv4       | 0.0.0.0/0  | Allow SSH access                            |
| tcp      | ingress   | 443        | 443      | IPv4       | 0.0.0.0/0  | Allow HTTPS traffic                         |
| tcp      | ingress   | 80         | 80       | IPv4       | 0.0.0.0/0  | Allow HTTP traffic                          |
| tcp      | ingress   | 3478       | 3478     | IPv4       | 0.0.0.0/0  | Allow alternative STUN/TURN traffic over TCP|
| udp      | ingress   | 3478       | 3478     | IPv4       | Any        | Allow STUN/TURN traffic for Coturn          |
| udp      | ingress   | 49152      |  65535   | IPv4       | 0.0.0.0/0  | Allow calling traffic for Coturn over UDP   |

- Note: If outbound traffic is restricted, port range mentioned [here](https://docs.wire.com/understand/notes/port-ranges.html) should be followed.

## Steps to Deploy WIAB from local environment (or on stackIT node)

### 1. Clone the repository
   - `git clone https://github.com/wireapp/wire-server-deploy.git`
   - `cd wire-server-deploy`

### 2. Prepare the variables for Wire deployment
- Prepare DNS records, StackIT public IP and set up Cert Manager (for example, letsencrypt) to start before next step as mentioned [here](https://docs.wire.com/how-to/install/helm.html#how-to-set-up-dns-records).
   - Check file `stackIT/host.ini` for host details, replace example.com with the host machine.
   - Check file `stackIT/stackit-vm-setup.yml` to define target_domain, replace example.com with the desired base domain of your Wire deployment - Ansible tasks will take care of other replacement operations.
   - Check file `stackIT/setting-values.sh` for DNS records i.e. TARGET_SYSTEM and CERT_MASTER_EMAIL, replace example.com with the wire host domain, the bash script will take care of other replacement operations in helm chart values.
      - We have used letsencrypt for example for cert management.
      - If you intend to use something other than letsencrypt, then please follow the documentation [Acquiring / Deploying SSL Certificates](https://github.com/wireapp/wire-server-deploy/blob/master/offline/docs_ubuntu_22.04.md#acquiring--deploying-ssl-certificates) **post running all the steps in** [3. Commands to Run on the StackIT Node in directory wire-server-deploy](https://github.com/wireapp/wire-server-deploy/blob/master/offline/stackIT-wiab.md#3-commands-to-run-on-the-stackit-node-in-directory-wire-server-deploy), to deploy your own certificates.

### 3. Run the ansible playbook
- **Note**: The deployment of the Wire application uses two layers of Ansible playbooks. The first layer (used in this step) provisions the containers on the stackIT node, downloads the artifact, and configures the iptables rules. The second layer ([bin/offline-cluster.sh](https://github.com/wireapp/wire-server-deploy/blob/master/bin/offline-cluster.sh), used in step 3.2) is designed to configure the datastore services on the containers created by the first layer.

- Use the following command to set up the VM:
  ```bash
  ansible-playbook -i stackIT/host.ini stackIT/stackit-vm-setup.yml
  ```

- **Optional Skips:**
  The ansible playbook is seggregated into multiple blocks. The following variables can be used to control the flow of tasks in ansible-playbook, if required:
  ```bash
  -e skip_install=true
  -e skip_ssh=true
  -e skip_minikube=true
  -e skip_docker=true
  -e skip_inventory=true
  -e skip_download=true
  -e skip_iptables=true
  -e skip_disable_kubespray=true
  ```

- **The above command will accomplish the following tasks:**
  - Deploy a Minikube Kubernetes cluster using docker containers as base, and 4 Docker containers to support assethost and datastore requirements. The functionality of different nodes is explained [here](https://docs.wire.com/how-to/install/planning.html#production-installation-persistent-data-high-availability).
  - Generate `hosts.ini` based on the IPs of above containers for further ansible operations on containers. Read more [here](https://github.com/wireapp/wire-server-deploy/blob/master/offline/docs_ubuntu_22.04.md#example-hostsini).
  - Download wire-server-deploy artifacts in the user's home directory. Read more [here](https://github.com/wireapp/wire-server-deploy/blob/master/offline/docs_ubuntu_22.04.md#artifacts-provided-in-the-deployment-tarball)
  - Configure iptables rules to handle the traffic for k8s Nginx Controller and handle DNAT for Coturn  (used by Wire applications). Read more [here](https://github.com/wireapp/wire-server-deploy/blob/master/offline/docs_ubuntu_22.04.md#directing-traffic-to-wire).

---

### 3. Commands to Run on the StackIT Node in directory `wire-server-deploy`
#### Note: These commands can be collected to run inside a single script, here we have broken down the deployment into small collective steps. These commands can work only from the stackIT node and in the directory wire-server-deploy.

- **Load the environment:**
   ```bash
   source stackIT/offline-env.sh
   ```
   It will load WSD_CONTAINER container on your StackIT host and it has all the tools required to further deploy the services using ansible and helm charts on nodes. `d` is an alias to run the container with all the required tools.

   1. **Generate secrets:**
      ```bash
      bash -x bin/offline-secrets.sh
      ```

   2. **Set up and configure the environment:**
      Run the following to set up the AssetHost, loading containers for k8s cluster, sync time, cassandra, elasticsearch and minio:
      ```bash
      d bash -x bin/offline-cluster.sh
      ```

   3. **Deploy Helm charts:**
      Use the following script to set up Helm chart values and deploy them:
      ```bash
      d bash -x stackIT/setting-values.sh
      ```

---

### File Structure Highlights

- **Ansible Playbook Files:**
  - `stackIT/stackit-vm-setup.yml`

- **Environment Scripts:**
  - `stackIT/offline-env.sh`
  - `../bin/offline-secrets.sh`

- **Cluster and Helm Setup:**
  - `../bin/offline-cluster.sh`
  - `stackIT/setting-values.sh`

---

## Notes
-  Read all the files involved before executing them to understand defaults.

