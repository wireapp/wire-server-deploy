# StackIT Deployment and Configuration Guide

This guide outlines the steps to set up and deploy Wire in a StackIT environment, including DNS configuration, Minikube cluster creation, Docker container setup, and Helm chart deployment. Each task and its associated commands are provided for clarity and customization.

---

## Prerequisites

- ansible
- ssh, ssh key for the ansible user on StackIT VM

## Steps to Deploy WIAB from local environment

### 1. Clone the repository
   - `git clone https://github.com/wireapp/wire-server-deploy.git`
   - `cd wire-server-deploy`

### 2. Run the Ansible Playbook
- Prepare DNS records, StackIT public IP and set up Cert Manager (for example, letsencrypt) to start before next step as mentioned [here](https://docs.wire.com/how-to/install/helm.html#how-to-set-up-dns-records).
   - Check file `stackIT/host.ini` for host details, replace example.com with the host machine.
   - Check file `stackIT/stackit-vm-setup.yml` to define target_domain, replace example.com with the wire host domain - Ansible tasks will take care of other replacement operations.
   - Check file `stackIT/setting-values.sh` for DNS records i.e. TARGET_SYSTEM and CERT_MASTER_EMAIL, replace example.com with the wire host domain, the bash script will take care of other replacement operations in helm chart values.
      - We have used letsencrypt for example for cert management
- Use the following command to set up the VM:
  ```bash
  ansible-playbook -i stackIT/host.ini stackIT/stackit-vm-setup.yml
  ```

- **Optional Skips:**
  The ansible playbook is seggregated into multiple blocks. Use the following variables to control the flow of tasks in ansible-playbook:
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
  - Minikube Kubernetes cluster and four Docker containers to support node requirements.
  - Generate `hosts.ini` based on the IPs of above containers for further ansible operations on node
  - Download wire-server-deploy artifacts based on the specified hash 
  - Configure iptables rules for DNAT to Coturn and k8s Nginx Controller (used by Wire applications).

---

### 3. Commands to Run on the StackIT Node in directory `wire-server-deploy`
#### Note: These commands can be collected to run inside a single script, here we have broken down the deployment into small collective steps.

- **Load the environment:**
   ```bash
   source stackIT/offline-env.sh
   ```
   It will load WSD_CONTAINER container on your StackIT host and it has all the tools required to further deploy the services using ansible and helm charts on nodes. `d` is an alias to run the container with all the required tools.

   1. **Generate secrets:**
      ```bash
      d bash -x bin/offline-secrets.sh
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

