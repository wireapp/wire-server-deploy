# High Availability Kubernetes Control Plane with kube-vip

## Table of Contents

1. [Overview](#overview)
2. [Why kube-vip?](#why-kube-vip)
3. [How kube-vip Works](#how-kube-vip-works)
4. [How Kubespray Integrates kube-vip](#how-kubespray-integrates-kube-vip)
5. [Choosing a Virtual IP (VIP)](#choosing-a-virtual-ip-vip)
6. [Configuration Reference](#configuration-reference)
7. [Installation Guide](#installation-guide)
8. [Testing and Verification](#testing-and-verification)
9. [Troubleshooting](#troubleshooting)
10. [References](#references)

---

## Overview

kube-vip provides Kubernetes clusters with a **Virtual IP (VIP)** for the control plane API server, enabling **High Availability (HA)** without requiring external load balancers. This is especially valuable for bare-metal, on-premises, and air-gapped deployments where cloud load balancers are unavailable.

### The Problem

In a multi-master Kubernetes cluster, when one control plane node fails, clients connecting directly to that node's IP address lose connectivity:

```
Client → kubenode1 (192.168.122.21:6443) ❌ [Node fails]
         kubenode2 (192.168.122.22:6443) ✅ [Still running]
         kubenode3 (192.168.122.23:6443) ✅ [Still running]
```

Without HA configuration, all kubeconfigs and kubelets point to the first control plane node, creating a **single point of failure**.

### The Solution: kube-vip

kube-vip creates a floating VIP that automatically fails over between healthy control plane nodes:

```
Client → VIP (192.168.122.100:6443) ✅ [Always available]
         ↓ (automatically routes to healthy node)
         kubenode1 (192.168.122.21:6443) ❌ [Node fails]
         kubenode2 (192.168.122.22:6443) ✅ [Active - owns VIP]
         kubenode3 (192.168.122.23:6443) ✅ [Standby]
```

---

## Why kube-vip?

### Comparison of HA Solutions

| Solution | Infrastructure Required | Setup Complexity | Best For |
|----------|------------------------|------------------|----------|
| **kube-vip** | None (Layer 2 ARP) | Low (built into Kubespray) | Bare-metal, on-prem, offline |
| Cloud LB | Cloud provider (AWS ELB, GCP LB) | Low (automated) | Cloud deployments |
| HAProxy + keepalived | External VMs/containers | High (manual setup) | Legacy environments |
| nginx localhost proxy | None | Low | Limited HA (per-node only) |

### Why kube-vip is the Best Choice for wire-server-deploy

1. **Zero External Dependencies**
   - No external load balancers required
   - No additional infrastructure costs
   - Works in air-gapped/offline environments

2. **Native Kubespray Integration**
   - Built into Kubespray v2.25+ (used by wire-server-deploy)
   - Automatic deployment and configuration
   - No manual installation steps

3. **True High Availability**
   - Automatic failover (typically <2 seconds)
   - Works for both internal (kubelet) and external (kubectl) clients
   - Single IP for all API server access

4. **Layer 2 Simplicity**
   - Uses standard ARP protocol (no BGP routing needed)
   - Works on any network with Layer 2 adjacency
   - No firewall rule changes required

5. **Production Ready**
   - Battle-tested in CNCF ecosystem
   - Active maintenance by kube-vip community
   - Used by major Kubernetes distributions

6. **Perfect for Hetzner/Bare-Metal**
   - Works on bare-metal servers
   - Compatible with virtual machines
   - No cloud-specific dependencies

### When NOT to Use kube-vip

- **Cloud environments with native LBs**: Use cloud provider load balancers (cheaper, integrated)
- **Routed Layer 3 networks**: Use BGP mode or external LB instead of ARP mode
- **Windows control plane nodes**: kube-vip requires Linux

---

## How kube-vip Works

### Architecture

kube-vip runs as a **static pod** on each control plane node and uses **leader election** to determine which node owns the VIP at any given time.

```
┌─────────────────────────────────────────────────────────────┐
│                        Control Plane                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │  kubenode1   │    │  kubenode2   │    │  kubenode3   │  │
│  │              │    │              │    │              │  │
│  │ kube-vip pod │    │ kube-vip pod │    │ kube-vip pod │  │
│  │  (standby)   │    │  (LEADER)    │    │  (standby)   │  │
│  │              │    │  OWNS VIP    │    │              │  │
│  └──────────────┘    └──────┬───────┘    └──────────────┘  │
│                              │                               │
│                              │ ARP Announcement             │
└──────────────────────────────┼───────────────────────────────┘
                               │
                     VIP: 192.168.122.100
                               │
                    ┌──────────▼──────────┐
                    │  Network switches   │
                    │  learn MAC address  │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │   Client requests   │
                    │   routed to leader  │
                    └─────────────────────┘
```

### Key Components

1. **Static Pod Manifest** (`/etc/kubernetes/manifests/kube-vip.yml`)
   - Deployed by Kubespray on each control plane node
   - Starts before kubelet is fully initialized
   - Ensures VIP is available during cluster bootstrap

2. **Leader Election**
   - Uses Kubernetes lease mechanism
   - Leader holds a lease named `plndr-cp-lock` in `kube-system` namespace
   - Lease renewed every 15 seconds (default)

3. **ARP Announcement**
   - Leader sends gratuitous ARP packets
   - Network learns VIP → Leader's MAC address mapping
   - Clients automatically route to the active leader

4. **Health Checks**
   - Monitors local API server health
   - If leader becomes unhealthy, releases lease
   - Standby node detects failure and takes over VIP

### Failover Process

When the leader node fails:

1. **Lease expires** (no renewal for 15-30 seconds)
2. **Standby nodes compete** for leadership
3. **New leader elected** via Kubernetes lease API
4. **New leader claims VIP** and sends ARP announcement
5. **Network updates** MAC address → new leader
6. **Clients reconnect** automatically (typically <2s downtime)

---

## How Kubespray Integrates kube-vip

Kubespray (used by wire-server-deploy) has **native kube-vip support** built-in since version 2.25.0. This integration is handled in the `kubernetes/node` role.

### Kubespray's Automatic Setup

When you enable kube-vip in your inventory, Kubespray automatically:

1. **Downloads kube-vip Image**
   - Pulls `ghcr.io/kube-vip/kube-vip:v0.8.0` (configurable)
   - Cached locally for offline deployments
   - Configured in `roles/kubespray-defaults/defaults/main/download.yml`

2. **Generates Static Pod Manifest**
   - Template: `roles/kubernetes/node/templates/manifests/kube-vip.manifest.j2`
   - Placed at: `/etc/kubernetes/manifests/kube-vip.yml`
   - Kubelet automatically starts the pod

3. **Validates Prerequisites**
   - Checks `kube_proxy_strict_arp: true` (required for ARP mode)
   - Verifies control plane node roles
   - Ensures network interface exists

4. **Configures API Server**
   - Updates `loadbalancer_apiserver` to use VIP
   - Adds VIP to API server certificate SANs
   - Configures kubeconfig with VIP endpoint

### Relevant Kubespray Code

```yaml
# File: ansible/roles-external/kubespray/roles/kubernetes/node/tasks/main.yml (line 24-30)
- name: Install kube-vip
  import_tasks: loadbalancer/kube-vip.yml
  when:
    - is_kube_master
    - kube_vip_enabled
  tags:
    - kube-vip
```

```yaml
# File: ansible/roles-external/kubespray/roles/kubernetes/node/tasks/loadbalancer/kube-vip.yml
- name: Kube-vip  | Check cluster settings for kube-vip
  fail:
    msg: "kube-vip require kube_proxy_strict_arp = true"
  when:
    - kube_proxy_mode == 'ipvs' and not kube_proxy_strict_arp
    - kube_vip_arp_enabled

- name: Kube-vip | Write static pod
  template:
    src: manifests/kube-vip.manifest.j2
    dest: "{{ kube_manifest_dir }}/kube-vip.yml"
    mode: 0640
```

### Kubespray Default Variables

```yaml
# File: ansible/roles-external/kubespray/roles/kubespray-defaults/defaults/main/main.yml
kube_vip_enabled: false  # Override in your inventory

# File: ansible/roles-external/kubespray/roles/kubespray-defaults/defaults/main/download.yml
kube_vip_image_repo: "{{ github_image_repo }}/kube-vip/kube-vip"
kube_vip_image_tag: v0.8.0
```

---

## Choosing a Virtual IP (VIP)

### Requirements for VIP Selection

The VIP must meet these criteria:

1. **Same subnet** as control plane nodes
2. **Unused/available** (not assigned to any host)
3. **Not in DHCP range** (to prevent conflicts)
4. **Routable** within your network
5. **Not a broadcast or network address**

### Step-by-Step VIP Selection

#### 1. Identify Your Control Plane Network

```bash
# SSH to any control plane node
ssh kubenode1

# Check IP and subnet
ip addr show enp1s0
```

Example output:
```
2: enp1s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
    inet 192.168.122.21/24 brd 192.168.122.255 scope global enp1s0
```

**Example Network information:**
- IP: `192.168.122.21`
- Subnet mask: `/24` (255.255.255.0)
- Network range: `192.168.122.0 - 192.168.122.255`
- Broadcast: `192.168.122.255`

#### 2. Check for Unused IPs

```bash
# Scan the subnet for unused IPs
nmap -sn 192.168.122.0/24

# Or use ping
for i in {1..254}; do
  ping -c 1 -W 1 192.168.122.$i > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "192.168.122.$i is available"
  fi
done
```

#### 3. Verify No DHCP Conflict

Check your DHCP server configuration to ensure the chosen IP is outside the DHCP range.

Example DHCP configuration:
```
# DHCP range: 192.168.122.50 - 192.168.122.200
# Safe VIP choices: 192.168.122.2 - 192.168.122.49
#                   192.168.122.201 - 192.168.122.254
```

#### 4. Test VIP Availability

```bash
# From a control plane node
ping -c 5 192.168.122.100 # change with the IP used for VIP

# Should show: "Destination Host Unreachable" or 100% packet loss
```

#### 5. Document Reserved IP

Add the VIP to your network documentation to prevent future conflicts:

```
# /etc/hosts or DNS records
192.168.122.100  k8s-api.example.com  # kube-vip VIP for Kubernetes API
```

### VIP Selection Examples

#### Example 1: Small Network (192.168.1.0/24)

```
Control plane nodes: 192.168.1.10, 192.168.1.11, 192.168.1.12
DHCP range:         192.168.1.100 - 192.168.1.200
Good VIP choice:    192.168.1.5 (near control plane, outside DHCP)
```

#### Example 2: Hetzner Cloud (10.0.0.0/24)

```
Control plane nodes: 10.0.0.2, 10.0.0.3, 10.0.0.4
DHCP range:         10.0.0.10 - 10.0.0.250
Good VIP choice:    10.0.0.5 (contiguous with nodes, easy to remember)
```

#### Example 3: Large Network (172.16.0.0/16)

```
Control plane subnet: 172.16.10.0/24
Control plane nodes:  172.16.10.11, 172.16.10.12, 172.16.10.13
DHCP range:          172.16.10.50 - 172.16.10.200
Good VIP choice:     172.16.10.10 (easy pattern, outside DHCP)
```

### VIP Best Practices

✅ **DO:**
- Choose an IP near your control plane nodes (easy to remember)
- Use a "round" number (e.g., .10, .100, .200)
- Document the VIP in network inventory
- Test availability before deployment
- Reserve the IP in DHCP server (exclusion)

❌ **DON'T:**
- Use .1 (often router/gateway)
- Use .255 (broadcast address)
- Use random high numbers (hard to remember)
- Pick an IP in DHCP range
- Use an IP from a different subnet

---

## Configuration Reference

### Complete Configuration Variables

All configuration is done in the Ansible inventory's `group_vars/k8s-cluster/` directory.

#### Required Variables

```yaml
# File: ansible/inventory/offline/group_vars/k8s-cluster/k8s-cluster.yml

# Enable kube-vip
kube_vip_enabled: true

# Enable control plane VIP (required for HA)
kube_vip_controlplane_enabled: true

# The Virtual IP address
kube_vip_address: "192.168.122.100"

# Network interface to bind VIP to
kube_vip_interface: "enp1s0"

# Use ARP for Layer 2 VIP management
kube_vip_arp_enabled: true

# Required for kube-vip ARP mode
kube_proxy_strict_arp: true
```

#### API Server Configuration

```yaml
# Configure API server to advertise VIP
apiserver_loadbalancer_domain_name: "192.168.122.100"

# Configure load balancer endpoint
loadbalancer_apiserver:
  address: "192.168.122.100"
  port: 6443

# Disable localhost load balancer (not needed with VIP)
loadbalancer_apiserver_localhost: false
```

#### Certificate Configuration

```yaml
# Add VIP to API server SSL certificates
supplementary_addresses_in_ssl_keys:
  - "192.168.122.100"
```

### Optional Variables

```yaml
# Use kube-vip for LoadBalancer services (not just control plane)
kube_vip_services_enabled: false  # Recommended: false for control plane only

# Use BGP instead of ARP (for routed Layer 3 networks)
kube_vip_bgp_enabled: false
kube_vip_bgp_routerid: "192.168.122.1"
kube_vip_bgp_as: 65000
kube_vip_bgp_peeraddress: "192.168.122.1"
kube_vip_bgp_peeras: 65000

# Custom kube-vip image (for air-gapped deployments)
kube_vip_image_repo: "ghcr.io/kube-vip/kube-vip"
kube_vip_image_tag: "v0.8.0"

# Leader election configuration (advanced)
kube_vip_lease_duration: "15s"
kube_vip_renew_deadline: "10s"
kube_vip_retry_period: "2s"
```

### Variable Reference Table

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `kube_vip_enabled` | Yes | `false` | Enable kube-vip |
| `kube_vip_controlplane_enabled` | Yes | - | Enable control plane VIP |
| `kube_vip_address` | Yes | - | Virtual IP address |
| `kube_vip_interface` | Yes | - | Network interface name |
| `kube_vip_arp_enabled` | Yes* | - | Use ARP for Layer 2 |
| `kube_proxy_strict_arp` | Yes* | `false` | Required when using ARP mode |
| `loadbalancer_apiserver` | Yes | - | API server endpoint config |
| `supplementary_addresses_in_ssl_keys` | Yes | - | Add VIP to certificates |
| `kube_vip_services_enabled` | No | `false` | Enable LoadBalancer services |
| `kube_vip_bgp_enabled` | No | `false` | Use BGP instead of ARP |
| `apiserver_loadbalancer_domain_name` | Recommended | - | API server advertise address |
| `loadbalancer_apiserver_localhost` | Recommended | `true` | Disable for VIP setup |

\* Required when using ARP mode (Layer 2). For BGP mode (Layer 3), use `kube_vip_bgp_enabled: true` instead.

### Network Interface Detection

To find your network interface name:

```bash
# SSH to a control plane node
ssh kubenode1

# List network interfaces
ip link show

# Or filter for active interfaces
ip -br addr show | grep UP
```

Common interface names:
- **eth0** - Traditional naming
- **enp1s0** - Predictable naming (PCI bus 1, slot 0)
- **ens3** - Predictable naming (hotplug slot 3)
- **eno1** - Onboard device naming

---

## Installation Guide

### Prerequisites

Before starting, ensure:

1. ✅ **Kubespray initialized**
   ```bash
   git submodule update --init ansible/roles-external/kubespray
   ```

2. ✅ **Inventory configured** with control plane nodes
   - Check `ansible/inventory/offline/hosts.ini`
   - Uncomment and configure `[kube-master]`, `[kube-node]`, `[etcd]` sections

3. ✅ **SSH access** to all nodes
   ```bash
   ssh kubenode1 'echo "SSH working"'
   ```

4. ✅ **VIP selected** and verified available

5. ✅ **Network interface name** identified

### Installation Steps

#### Step 1: Create kube-vip Configuration

```bash
# Create the directory
mkdir -p ansible/inventory/offline/group_vars/k8s-cluster

# Create the configuration file
cat > ansible/inventory/offline/group_vars/k8s-cluster/k8s-cluster.yml << 'EOF'
---
# kube-vip for control plane HA with VIP
kube_vip_enabled: true
kube_vip_controlplane_enabled: true
kube_vip_address: "192.168.122.100"  # CHANGE THIS
kube_vip_interface: "enp1s0"         # CHANGE THIS
kube_vip_arp_enabled: true
kube_vip_services_enabled: false

# Configure API server domain name
apiserver_loadbalancer_domain_name: "192.168.122.100"

# Required for kube-vip with ARP mode
kube_proxy_strict_arp: true

# Configure API server endpoint to use VIP
loadbalancer_apiserver:
  address: "192.168.122.100"  # CHANGE THIS
  port: 6443

# Disable localhost LB since we have VIP
loadbalancer_apiserver_localhost: false

# Add VIP to API server SSL certificates
supplementary_addresses_in_ssl_keys:
  - "192.168.122.100"  # CHANGE THIS
EOF
```

**Important:** Replace `192.168.122.100` with your chosen VIP and `enp1s0` with your interface name.

#### Step 2: Configure Inventory

Ensure your inventory file has control plane nodes defined:

```ini
# File: ansible/inventory/offline/99-static

[all]
kubenode1 ansible_host=192.168.122.21 ip=192.168.122.21
kubenode2 ansible_host=192.168.122.22 ip=192.168.122.22
kubenode3 ansible_host=192.168.122.23 ip=192.168.122.23

[kube-master]
kubenode1
kubenode2
kubenode3

[etcd]
kubenode1 etcd_member_name=etcd1
kubenode2 etcd_member_name=etcd2
kubenode3 etcd_member_name=etcd3

[kube-node]
kubenode1
kubenode2
kubenode3

[k8s-cluster:children]
kube-master
kube-node
```

#### Step 3: Deploy Kubernetes with kube-vip

For a **new cluster**:

```bash
# Deploy full Kubernetes cluster with kube-vip
ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/kubernetes.yml
```

For an **existing cluster** (adding kube-vip):

```bash
# Deploy only kube-vip and update control plane
ansible-playbook -i ansible/inventory/offline/hosts.ini \
  ansible/kubernetes.yml \
  --tags=node,kube-vip,master
```

Expected output:
```
PLAY [Install Kubernetes nodes] *******************************************

TASK [kubernetes/node : Install kube-vip] *********************************
included: /path/to/kubespray/roles/kubernetes/node/tasks/loadbalancer/kube-vip.yml

TASK [kubernetes/node : Kube-vip | Check cluster settings for kube-vip] ***
ok: [kubenode1]

TASK [kubernetes/node : Kube-vip | Write static pod] **********************
changed: [kubenode1]
changed: [kubenode2]
changed: [kubenode3]

PLAY RECAP ****************************************************************
kubenode1    : ok=45   changed=3    failed=0
kubenode2    : ok=42   changed=3    failed=0
kubenode3    : ok=42   changed=3    failed=0
```

#### Step 4: Wait for kube-vip Pods

```bash
# SSH to a control plane node
ssh kubenode1

# Wait for kube-vip static pods to start (may take 30-60 seconds)
watch kubectl get pods -n kube-system -l component=kube-vip
```

Expected output:
```
NAME                       READY   STATUS    RESTARTS   AGE
kube-vip-kubenode1         1/1     Running   0          45s
kube-vip-kubenode2         1/1     Running   0          45s
kube-vip-kubenode3         1/1     Running   0          45s
```

#### Step 5: Update Local Kubeconfig

```bash
# Copy kubeconfig from artifacts
export KUBECONFIG=ansible/inventory/offline/artifacts/admin.conf

# Verify it uses VIP
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
# Should output: https://192.168.122.100:6443
```

If not using VIP, update manually:

```bash
kubectl config set-cluster cluster.local --server=https://192.168.122.100:6443
```

---

## Testing and Verification

### 1. Verify VIP is Active

```bash
# SSH to each control plane node and check if VIP is present
ssh kubenode1 "ip addr show enp1s0 | grep 192.168.122.100"
ssh kubenode2 "ip addr show enp1s0 | grep 192.168.122.100"
ssh kubenode3 "ip addr show enp1s0 | grep 192.168.122.100"
```

**Expected result:** VIP should appear on exactly **one** node (the leader).

Example output from leader:
```
inet 192.168.122.21/24 brd 192.168.122.255 scope global enp1s0
inet 192.168.122.100/32 scope global enp1s0  # <-- VIP present
```

### 2. Check kube-vip Leader Election

```bash
# Check which node is the leader
# Note: The lease is named "plndr-cp-lock" (legacy name from kube-vip's previous project)
kubectl get lease -n kube-system plndr-cp-lock -o jsonpath='{.spec.holderIdentity}'
# Output: kubenode2 (or whichever node is current leader)
```

### 3. Test API Server Connectivity via VIP

```bash
# From your local machine (outside cluster)
export KUBECONFIG=ansible/inventory/offline/artifacts/admin.conf

# Test API connectivity
kubectl get nodes
kubectl cluster-info
```

Expected output:
```
NAME        STATUS   ROLES           AGE   VERSION
kubenode1   Ready    control-plane   10m   v1.29.10
kubenode2   Ready    control-plane   10m   v1.29.10
kubenode3   Ready    control-plane   10m   v1.29.10

Kubernetes control plane is running at https://192.168.122.100:6443
```

### 4. Test Failover (Simulated Node Failure)

This is the **critical test** to verify HA works correctly.

```bash
# Identify current leader
LEADER=$(kubectl get lease -n kube-system plndr-cp-lock -o jsonpath='{.spec.holderIdentity}')
echo "Current leader: $LEADER"

# SSH to leader and stop kubelet (simulates node failure)
ssh $LEADER "sudo systemctl stop kubelet"

# Watch VIP failover (should complete in <5 seconds)
watch -n 1 'kubectl get lease -n kube-system plndr-cp-lock -o jsonpath="{.spec.holderIdentity}"; echo'

# Test API connectivity during failover
while true; do
  kubectl get nodes --request-timeout=2s > /dev/null 2>&1 && echo "✅ API reachable" || echo "❌ API unavailable"
  sleep 1
done
```

**Expected behavior:**
1. Leader changes to a different node within 5-10 seconds
2. API may be briefly unavailable (1-3 seconds)
3. All subsequent requests succeed

```bash
# Restore the stopped node
ssh $LEADER "sudo systemctl start kubelet"
```

### 5. Verify ARP Table Updates

From a node on the same network:

```bash
# Check ARP table for VIP
ip neigh show 192.168.122.100

# Should show the MAC address of the current leader node
# Example: 192.168.122.100 dev eth0 lladdr 52:54:00:12:34:56 REACHABLE
```

### 6. Check kube-vip Logs

```bash
# View logs from current leader
LEADER=$(kubectl get lease -n kube-system plndr-cp-lock -o jsonpath='{.spec.holderIdentity}')
ssh $LEADER "sudo crictl logs $(sudo crictl ps | grep kube-vip | awk '{print $1}')"

# Or view logs using kubectl
kubectl logs -n kube-system kube-vip-kubenode1
```

Expected log entries:
```
time="2024-11-19T09:00:00Z" level=info msg="Starting kube-vip"
time="2024-11-19T09:00:01Z" level=info msg="Starting Leader Election"
time="2024-11-19T09:00:05Z" level=info msg="Acquired leadership, starting VIP"
time="2024-11-19T09:00:05Z" level=info msg="Broadcasting ARP for 192.168.122.100"
```

### 7. Load Test (Optional)

Test API server under load during failover:

```bash
# Terminal 1: Generate continuous API requests
while true; do
  kubectl get nodes --request-timeout=1s
  sleep 0.5
done

# Terminal 2: Force failover
LEADER=$(kubectl get lease -n kube-system plndr-cp-lock -o jsonpath='{.spec.holderIdentity}')
ssh $LEADER "sudo systemctl stop kubelet"

# Monitor success rate in Terminal 1
# Expect: <1% failure rate during failover window
```

### Verification Checklist

- [ ] VIP appears on exactly one control plane node
- [ ] kube-vip pods running on all control plane nodes
- [ ] Leader election lease `plndr-cp-lock` exists in `kube-system` namespace
- [ ] API server accessible via VIP from external client
- [ ] Kubeconfig uses VIP address (not individual node IPs)
- [ ] Failover completes within 5 seconds when leader node fails
- [ ] API requests succeed through failover (minimal downtime)
- [ ] VIP returns to original node after restart (optional)
- [ ] ARP table shows correct MAC address for VIP
- [ ] No error messages in kube-vip logs

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: VIP Not Appearing on Any Node

**Symptoms:**
```bash
ssh kubenode1 "ip addr show enp1s0 | grep 192.168.122.100"
# No output
```

**Possible Causes:**

1. **kube-vip pods not running**
   ```bash
   kubectl get pods -n kube-system | grep kube-vip
   # Check STATUS column
   ```

   **Solution:** Check pod logs:
   ```bash
   kubectl logs -n kube-system kube-vip-kubenode1
   ```

2. **Wrong interface name**
   ```bash
   ssh kubenode1 "ip link show enp1s0"
   # interface enp1s0 does not exist
   ```

   **Solution:** Find correct interface and update config:
   ```bash
   ssh kubenode1 "ip -br link show"
   # Update kube_vip_interface in group_vars/k8s-cluster/k8s-cluster.yml
   ```

3. **Lease acquisition failure**
   ```bash
   kubectl get lease -n kube-system plndr-cp-lock
   # Error: leases.coordination.k8s.io "plndr-cp-lock" not found
   ```

   **Solution:** Check kube-vip logs for RBAC errors:
   ```bash
   # Look for "forbidden" or "unauthorized" messages
   kubectl logs -n kube-system kube-vip-kubenode1 | grep -i error
   ```

#### Issue 2: kube_proxy_strict_arp Error

**Symptoms:**
```
TASK [kubernetes/node : Kube-vip | Check cluster settings for kube-vip]
fatal: [kubenode1]: FAILED! => {
    "msg": "kube-vip require kube_proxy_strict_arp = true"
}
```

**Solution:**
```bash
# Add to group_vars/k8s-cluster/k8s-cluster.yml
echo "kube_proxy_strict_arp: true" >> ansible/inventory/offline/group_vars/k8s-cluster/k8s-cluster.yml

# Re-run playbook
ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/kubernetes.yml --tags=node,kube-vip
```

#### Issue 3: VIP Not Reachable from External Network

**Symptoms:**
```bash
# From external machine
ping 192.168.122.100
# Destination Host Unreachable
```

**Possible Causes:**

1. **VIP on wrong subnet**
   ```bash
   # Check control plane node subnet
   ssh kubenode1 "ip addr show enp1s0"
   # Ensure VIP is in the same /24 (or /16) network
   ```

2. **Firewall blocking traffic**
   ```bash
   # Check firewall rules on nodes
   ssh kubenode1 "sudo iptables -L -n | grep 6443"

   # Allow API server port if blocked
   ssh kubenode1 "sudo iptables -I INPUT -p tcp --dport 6443 -j ACCEPT"
   ```

3. **ARP not propagating**
   ```bash
   # From a node on the same network, check ARP table
   ip neigh show | grep 192.168.122.100

   # If missing, manually trigger ARP refresh
   arping -I enp1s0 -c 3 192.168.122.100
   ```

#### Issue 4: Failover Not Working

**Symptoms:**
```bash
# Stop leader node
ssh kubenode1 "sudo systemctl stop kubelet"

# VIP doesn't move to another node (after 30+ seconds)
ssh kubenode2 "ip addr show | grep 192.168.122.100"
# No output
```

**Diagnosis:**

1. **Check if standby nodes see leader failure**
   ```bash
   kubectl get lease -n kube-system plndr-cp-lock -o yaml
   # Check renewTime - should be stale (>30s old)
   ```

2. **Check standby kube-vip logs**
   ```bash
   ssh kubenode2 "sudo crictl logs $(sudo crictl ps | grep kube-vip | awk '{print $1}')"
   # Look for: "Attempting to acquire lease" or "Acquired leadership"

   # Or using kubectl
   kubectl logs -n kube-system kube-vip-kubenode2 | tail -50
   ```

3. **Verify network connectivity between nodes**
   ```bash
   ssh kubenode2 "ping -c 3 192.168.122.21"
   ssh kubenode2 "nc -zv 192.168.122.21 6443"
   ```

**Solution:** Restart kube-vip pods:
```bash
# Delete static pod manifest (kubelet will recreate it)
ssh kubenode2 "sudo rm /etc/kubernetes/manifests/kube-vip.yml"
sleep 5
ssh kubenode2 "sudo systemctl restart kubelet"
```

#### Issue 5: Certificate Errors After Enabling VIP

**Symptoms:**
```bash
kubectl get nodes
# Unable to connect to the server: x509: certificate is valid for 192.168.122.21, not 192.168.122.100
```

**Solution:** VIP not in certificate SANs. Add to config and regenerate certificates:

```bash
# Ensure this is in group_vars/k8s-cluster/k8s-cluster.yml
supplementary_addresses_in_ssl_keys:
  - "192.168.122.100"

# Regenerate certificates
ansible-playbook -i ansible/inventory/offline/hosts.ini \
  ansible/kubernetes.yml \
  --tags=master

# Or use Kubespray's certificate renewal playbook
ansible-playbook -i ansible/inventory/offline/hosts.ini \
  ansible/roles-external/kubespray/extra_playbooks/upgrade-only.yml \
  --tags=upgrade-certs
```

#### Issue 6: Multiple Nodes Claiming VIP (Split Brain)

**Symptoms:**
```bash
# VIP appears on multiple nodes simultaneously
ssh kubenode1 "ip addr show | grep 192.168.122.100"  # Present
ssh kubenode2 "ip addr show | grep 192.168.122.100"  # Present (BUG!)
```

**This is a critical issue.** Possible causes:

1. **Network partition** - Nodes can't communicate
2. **Lease API unavailable** - etcd or API server problems
3. **Time sync issues** - NTP drift between nodes

**Diagnosis:**
```bash
# Check if nodes can reach API server
ssh kubenode1 "curl -k https://127.0.0.1:6443/healthz"
ssh kubenode2 "curl -k https://127.0.0.1:6443/healthz"

# Check time sync
ssh kubenode1 "date +%s"
ssh kubenode2 "date +%s"
# Should be within 1-2 seconds

# Check lease status
kubectl get lease -n kube-system plndr-cp-lock -o yaml
```

**Solution:**
```bash
# Restart kube-vip on all nodes in sequence
for node in kubenode1 kubenode2 kubenode3; do
  ssh $node "sudo rm /etc/kubernetes/manifests/kube-vip.yml && sleep 5 && sudo systemctl restart kubelet"
  sleep 10
done

# Fix time sync if needed
for node in kubenode1 kubenode2 kubenode3; do
  ssh $node "sudo systemctl restart systemd-timesyncd"
done
```

#### Issue 7: Pods Can't Reach API Server via VIP

**Symptoms:**
```bash
# Inside a pod
kubectl exec -it mypod -- curl -k https://192.168.122.100:6443/healthz
# Connection timeout
```

**Cause:** VIP is Layer 2 (ARP) and only works for external traffic. Pods use internal Kubernetes service.

**Solution:** This is **expected behavior**. Pods should use the Kubernetes service:
```bash
# Pods automatically use this (injected by kubelet)
kubectl get svc kubernetes -n default
# NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
# kubernetes   ClusterIP   10.233.0.1   <none>        443/TCP   1h
```

No action needed - this is correct.

### Debug Commands Cheatsheet

```bash
# Check VIP assignment
for node in kubenode1 kubenode2 kubenode3; do
  echo "$node:"
  ssh $node "ip addr show | grep -A2 '192.168.122.100'"
done

# Check kube-vip pod status
kubectl get pods -n kube-system | grep kube-vip

# Check current leader
kubectl get lease -n kube-system plndr-cp-lock -o jsonpath='{.spec.holderIdentity}{"\n"}'

# View kube-vip logs from all nodes
for node in kubenode1 kubenode2 kubenode3; do
  echo "=== $node ==="
  kubectl logs -n kube-system kube-vip-$node
done

# Check API server certificate SANs
echo | openssl s_client -connect 192.168.122.100:6443 -showcerts 2>/dev/null | \
  openssl x509 -noout -text | grep -A1 "Subject Alternative Name"

# Check ARP table on all nodes
for node in kubenode1 kubenode2 kubenode3; do
  echo "$node:"
  ssh $node "ip neigh show 192.168.122.100"
done

# Force leader election (for testing)
kubectl delete lease -n kube-system plndr-cp-lock

# Check kube-proxy mode
kubectl get configmap -n kube-system kube-proxy -o yaml | grep mode

# Verify strict ARP setting
kubectl get configmap -n kube-system kube-proxy -o yaml | grep strictARP
```

### Getting Help

If issues persist:

1. **Check kube-vip GitHub issues**: https://github.com/kube-vip/kube-vip/issues
2. **Review Kubespray documentation**: https://github.com/kubernetes-sigs/kubespray
3. **Wire server-deploy issues**: https://github.com/wireapp/wire-server-deploy/issues
4. **Include diagnostic information:**
   ```bash
   # Gather diagnostic bundle
   kubectl cluster-info dump --output-directory=/tmp/k8s-debug

   # Collect kube-vip logs
   for node in kubenode{1..3}; do
     ssh $node "sudo crictl logs \$(sudo crictl ps --name kube-vip -q)" \
       > /tmp/kube-vip-$node.log 2>&1
   done
   ```

---

## References

### Official Documentation

- **kube-vip Project**: https://kube-vip.io/
- **kube-vip GitHub**: https://github.com/kube-vip/kube-vip
- **Kubespray Documentation**: https://github.com/kubernetes-sigs/kubespray

### wire-server-deploy References

- **Main Repository**: https://github.com/wireapp/wire-server-deploy
- **Inventory Configuration**: ansible/inventory/offline/group_vars/k8s-cluster/k8s-cluster.yml
- **Kubespray Integration**: ansible/kubernetes.yml

### Kubespray kube-vip Implementation

- **kube-vip Role**: ansible/roles-external/kubespray/roles/kubernetes/node/tasks/loadbalancer/kube-vip.yml
- **kube-vip Template**: ansible/roles-external/kubespray/roles/kubernetes/node/templates/manifests/kube-vip.manifest.j2
- **Default Variables**: ansible/roles-external/kubespray/roles/kubespray-defaults/defaults/main/main.yml
- **Image Configuration**: ansible/roles-external/kubespray/roles/kubespray-defaults/defaults/main/download.yml

### Related Technologies

- **VRRP (Virtual Router Redundancy Protocol)**: RFC 5798
- **ARP (Address Resolution Protocol)**: RFC 826
- **Kubernetes Leases**: https://kubernetes.io/docs/concepts/architecture/leases/
- **Kubernetes HA**: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/

### Version Information

- **Kubespray Version**: v2.25.1+ (used by wire-server-deploy)
- **kube-vip Version**: v0.8.0 (default in Kubespray v2.25.1)
- **Kubernetes Version**: v1.29.10 (as configured in wire-server-deploy)
- **Supported OS**: Ubuntu 22.04, Debian 11/12, Rocky Linux 9

---

## Appendix: Example Configurations

### Example 1: Basic 3-Node Cluster

```yaml
# File: ansible/inventory/offline/group_vars/k8s-cluster/k8s-cluster.yml
---
kube_vip_enabled: true
kube_vip_controlplane_enabled: true
kube_vip_address: "10.0.1.100"
kube_vip_interface: "eth0"
kube_vip_arp_enabled: true
kube_vip_services_enabled: false

apiserver_loadbalancer_domain_name: "10.0.1.100"
kube_proxy_strict_arp: true

loadbalancer_apiserver:
  address: "10.0.1.100"
  port: 6443

loadbalancer_apiserver_localhost: false

supplementary_addresses_in_ssl_keys:
  - "10.0.1.100"
```

### Example 2: With DNS Name

```yaml
---
kube_vip_enabled: true
kube_vip_controlplane_enabled: true
kube_vip_address: "192.168.1.10"
kube_vip_interface: "ens18"
kube_vip_arp_enabled: true
kube_vip_services_enabled: false

# Use DNS name for better readability
apiserver_loadbalancer_domain_name: "k8s-api.example.com"
kube_proxy_strict_arp: true

loadbalancer_apiserver:
  address: "192.168.1.10"  # Resolve k8s-api.example.com to this IP in DNS
  port: 6443

loadbalancer_apiserver_localhost: false

supplementary_addresses_in_ssl_keys:
  - "192.168.1.10"
  - "k8s-api.example.com"
```

### Example 3: Offline/Air-Gapped Deployment

```yaml
---
kube_vip_enabled: true
kube_vip_controlplane_enabled: true
kube_vip_address: "172.16.0.10"
kube_vip_interface: "enp1s0"
kube_vip_arp_enabled: true
kube_vip_services_enabled: false

# Use local container registry for offline deployment
kube_vip_image_repo: "registry.local:5000/kube-vip/kube-vip"
kube_vip_image_tag: "v0.8.0"

apiserver_loadbalancer_domain_name: "172.16.0.10"
kube_proxy_strict_arp: true

loadbalancer_apiserver:
  address: "172.16.0.10"
  port: 6443

loadbalancer_apiserver_localhost: false

supplementary_addresses_in_ssl_keys:
  - "172.16.0.10"
```

### Example 4: Large Cluster with BGP (Advanced)

For routed Layer 3 networks (data centers with BGP):

```yaml
---
kube_vip_enabled: true
kube_vip_controlplane_enabled: true
kube_vip_address: "10.100.0.10"
kube_vip_interface: "ens192"

# Use BGP instead of ARP
kube_vip_arp_enabled: false
kube_vip_bgp_enabled: true
kube_vip_bgp_routerid: "10.100.0.10"
kube_vip_bgp_as: 65001
kube_vip_bgp_peeraddress: "10.100.0.1"  # BGP router
kube_vip_bgp_peeras: 65000

kube_vip_services_enabled: false

apiserver_loadbalancer_domain_name: "10.100.0.10"

# BGP doesn't require strict ARP
kube_proxy_strict_arp: false

loadbalancer_apiserver:
  address: "10.100.0.10"
  port: 6443

loadbalancer_apiserver_localhost: false

supplementary_addresses_in_ssl_keys:
  - "10.100.0.10"
```

---

## Summary

kube-vip provides a **simple, reliable, and production-ready** solution for Kubernetes control plane high availability in wire-server-deploy. With native Kubespray integration, deployment is as simple as adding a few configuration variables to your inventory.

**Key Takeaways:**

✅ **Zero external dependencies** - Works on any network with Layer 2 connectivity
✅ **Automatic failover** - Leader election ensures VIP always points to a healthy node
✅ **Built into Kubespray** - No manual installation or configuration required
✅ **Production proven** - Used by many organizations in bare-metal Kubernetes deployments
✅ **Perfect for Hetzner/offline** - Works in air-gapped and cloud environments

By following this guide, you now have a fully redundant Kubernetes control plane that can survive node failures without service interruption.

---

**Document Version**: 1.0
**Last Updated**: 2024-11-20
**Tested with**:
- wire-server-deploy: master branch
- Kubespray: v2.25.1
- kube-vip: v0.8.0
- Kubernetes: v1.29.10
