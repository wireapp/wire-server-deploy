# StackIT Deployment and Configuration Guide

This guide outlines the steps to set up and deploy Wire in a StackIT environment, including DNS configuration, Minikube cluster creation, Docker container setup, and Helm chart deployment. Each task and its associated commands are provided for clarity and customization.

---

## Steps to Deploy

### 1. Run the Ansible Playbook
- Prepare DNS records, StackIT public IP and set up Cert Manager to start before next step as mentioned [here](https://docs.wire.com/how-to/install/helm.html#how-to-set-up-dns-records). 
   - Check file `stackIT/host.ini` for host details
   - Check file `stackIT/setting-values.sh` for DNS records i.e. TARGET_SYSTEM and CERT_MASTER_EMAIL
      - We have used letsencrypt for example for cert management
- Use the following command to set up the VM:
  ```bash
  ansible-playbook -i stackIT/host.ini stackIT/stackit-vm-setup.yml --private-key ~/.ssh/stackit_private_key
  ```

- **Optional Skips:**
  The ansible playbook is seggregated into multiple blocks. Use the following variables to control the flow of tasks:
  ```bash
  -e skip_install=true
  -e skip_ssh=true
  -e skip_minikube=true
  -e skip_docker=true
  -e skip_inventory=true
  -e skip_download=true
  -e skip_iptables=true
  ```

- **Artifacts and Tasks:**
  - Minikube Kubernetes cluster and four Docker containers to support node requirements.
  - Generate `hosts.ini` based on the IPs of above containers for further ansible operations on node
  - Download wire-server-deploy artifacts based on the specified hash 
  - Configure iptables rules for DNAT to Coturn and k8s Nginx Controller (used by Wire applications).

---

### 2. Commands to Run on the StackIT Nodes in directory `wire-server-deploy`

1. **Load the environment:**
   ```bash
   source stackIT/offline-env.sh
   ```

2. **Generate secrets:**
   ```bash
   bash -x bin/offline-secrets.sh
   ```

3. **Access the environment:**
   ```bash
   d bash
   ```

4. **Set up and configure the environment:**
   Run the following to set up the AssetHost, loading containers for k8s cluster, sync time, cassandra, elasticsearch and minio:
   ```bash
   bash -x bin/offline-cluster.sh
   ```

5. **Deploy Helm charts:**
   Use the following script to set up Helm chart values and deploy them:
   ```bash
   bash -x stackIT/setting-values.sh
   ```

---

## To-Dos

1. **Modify `bin/offline-env.sh`:**
   - Add definitions for Kubernetes config for kubectl for non-kubespray environments like in stackIT
   - When Copying ssh env from the host drop or re-initialize the known_hosts to avoid ip change clashes

2. **Update `bin/offline-cluster.sh`:**
   - Remove references to `restund.yml`.
   - Introduce a check for Kubespray to avoid execution if Minikube is already running.

3. **Enhance Helm charts:**
   - Ensure pods reload when there are changes in:
     - ConfigMaps.
     - Environment variables.
     - Public IPs parsed at pod startup.
   - Introduce hashing to track changes and trigger restarts as needed.
   - Current upgrades don't restart the pods for example, sftd and coturn

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

