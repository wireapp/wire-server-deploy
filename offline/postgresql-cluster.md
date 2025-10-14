# PostgreSQL High Availability Cluster Deployment Guide

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Key Concepts](#key-concepts)
- [Minimum System Requirements](#minimum-system-requirements)
- [High Availability Features](#high-availability-features)
- [Inventory Definition](#inventory-definition)
- [Installation Process](#installation-process)
- [Deployment Commands Reference](#deployment-commands-reference)
- [Monitoring Checks After Installation](#monitoring-checks-after-installation)
- [Configuration Options](#configuration-options)
- [Node Recovery Operations](#node-recovery-operations)
- [How It Confirms a Reliable System](#how-it-confirms-a-reliable-system)
- [Kubernetes Integration](#kubernetes-integration)
- [Wire Server Database Setup](#wire-server-database-setup)

## Architecture Overview

**Primary-Replica HA Architecture** with intelligent split-brain protection and automatic failover:

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ PostgreSQL1 │    │ PostgreSQL2 │    │ PostgreSQL3 │
│  (Primary)  │───▶│  (Replica)  │    │  (Replica)  │
│ Read/Write  │    │ Read-Only   │    │ Read-Only   │
└─────────────┘    └─────────────┘    └─────────────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           │
              ┌─────────────────────────────┐
              │    Split-Brain Protection   │
              │    & Automatic Failover     │
              └─────────────────────────────┘
```

**Core Components:**
- **PostgreSQL 17**: Streaming replication with performance improvements
- **repmgr**: Cluster management and automatic failover orchestration
- **Split-Brain Detection**: Prevents data corruption scenarios
- **Event-Driven Recovery**: Automatic cluster state management

## Key Concepts

### Technology Stack
- **PostgreSQL 17**: Latest stable version with streaming replication ([docs](https://www.postgresql.org/docs/17/warm-standby.html))
- **repmgr/repmgrd**: Cluster management and automatic failover ([docs](https://repmgr.org/))
- **Split-Brain Detection**: Intelligent monitoring prevents data corruption
- **Wire Integration**: Pre-configured database setup
- **Offline Deployment**: For offline deployments, packages are installed from local URLs defined in [`ansible/inventory/offline/group_vars/postgresql/postgresql.yml`](ansible/inventory/offline/group_vars/postgresql/postgresql.yml), bypassing repositories.

### Software Versions
- **PostgreSQL**: 17.5 (latest stable with enhanced replication features)
- **repmgr**: 5.5.0 (production-ready cluster management with advanced failover) ([docs](https://repmgr.org/docs/current/))
- **Ubuntu/Debian**: 20.04+ / 11+ (tested platforms for production deployment)

## Minimum System Requirements

Based on the PostgreSQL configuration template, the deployment is optimized for resource-constrained environments:

**Memory Requirements:**
- **RAM**: 1GB minimum per node (based on configuration tuning)
  - `shared_buffers = 256MB` (25% of total RAM)
  - `effective_cache_size = 512MB` (50% of total RAM estimate)
  - `maintenance_work_mem = 64MB`
  - `work_mem = 2MB` per connection (with `max_connections = 20`)

**CPU Requirements:**
- **Cores**: 1 CPU core minimum
  - `max_parallel_workers_per_gather = 0` (parallel queries disabled)
  - `max_parallel_workers = 1`
  - `max_worker_processes = 2` (minimum for repmgr operations)

**Storage Requirements:**
- **Disk Space**: 50GB minimum per node
  - `wal_keep_size = 2GB` (4% of disk)
  - `max_slot_wal_keep_size = 3GB` (6% of disk)
  - `max_wal_size = 1GB` (2% of disk)
  - Additional space for PostgreSQL data directory and logs

**Operating System Requirements:**
- **Linux Distribution**: Ubuntu/Debian (systemd-based)
- **Filesystem**: ext4/xfs (configured with `wal_sync_method = fdatasync`)
- **Package Management**: apt-based package installation

**Network Requirements:**
- **PostgreSQL Port**: 5432 open between all cluster nodes

**Note**: Configuration supports up to 20 concurrent connections. For production workloads with higher loads, scale up resources accordingly.

**⚠️ Important**: Review and optimize the [PostgreSQL configuration template](../ansible/templates/postgresql/postgresql.conf.j2) based on your specific hardware, workload, and performance requirements before deployment.

## High Availability Features
- **Detection**: repmgrd monitors primary connectivity with configurable timeouts ([repmgr failover](https://repmgr.org/docs/current/failover.html))
- **Failover Validation**: Quorum-based promotion with lag checking and connectivity validation
- **Promotion**: Promotes replica with most recent data automatically
- **Rewiring**: Remaining replicas connect to new primary automatically

**Failover Validation Features:**
- **Quorum Requirements**: For 3+ node clusters, requires ≥2 visible nodes for promotion
- **Lag Validation**: Checks WAL replay lag against configurable threshold (64MB default)
- **Recovery State**: Ensures candidate is in recovery mode before promotion
- **Connectivity Checks**: Validates WAL receiver activity

### 🛡️ Split-Brain Protection

**Detection Logic:**
1. **Self-Check**: Am I an isolated primary? (no active replicas connected)
2. **Cross-Node Verification**: Query all other cluster nodes to detect conflicting primaries
3. **Conflict Resolution**: If split-brain detected → mask and stop PostgreSQL service

**Advanced Features:**
- **Multi-Node Checking**: Verifies primary status across all cluster nodes
- **Graceful Shutdown**: Masks service to prevent restart attempts, then stops PostgreSQL
- **Force Termination**: Uses `systemctl kill` if normal stop fails
- **Event Logging**: Comprehensive logging to syslog and journal

**Recovery:** Event-driven fence script updates node status in the repmgr database and automatically unmasks services during successful rejoins (manual unmasking required for split-brain resolution)

### 🔄 Self-Healing Capabilities

| Scenario | Detection | Recovery Time | Data Loss |
|----------|-----------|---------------|-----------|
| Primary Failure | 25-60 seconds | < 30 seconds | None |
| Network Partition | 30-120 seconds | Automatic | None |
| Node Recovery | Immediate | < 2 minutes | None |

**Primary Failure**: repmgrd monitors connectivity (2s intervals), confirms failure after 5 attempts (~10s), validates quorum (≥2 nodes for 3+ clusters), selects best replica by priority/lag, promotes automatically with zero data loss.

**Network Partition**: 30s timer triggers cross-node verification, isolates conflicting primaries by masking/stopping services, auto-recovers when network restores with timeline synchronization if needed.

**Node Recovery**: Auto-starts in standby mode, connects to current primary, uses pg_rewind for timeline divergence, registers with repmgr, catches up via WAL streaming within 2 minutes.

### 📊 Monitoring & Event System

**Automated split-brain detection** runs every 30 seconds via systemd timer, with cross-node verification to prevent data corruption. Event-driven fence scripts handle service masking/unmasking during cluster state changes.

**Key monitoring commands:**
- Cluster status: `sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf cluster show`
- Service status: `sudo systemctl status postgresql@17-main repmgrd@17-main detect-rogue-primary.timer`
- Replication status: `sudo -u postgres psql -c "SELECT application_name, client_addr, state FROM pg_stat_replication;"`
- Logs: `sudo journalctl -u detect-rogue-primary.service --since "10m ago"`

## Inventory Definition

The PostgreSQL cluster requires a properly structured inventory to define node roles and configuration. The inventory file should be located at `ansible/inventory/offline/hosts.ini` or your specific environment path.

### Inventory Structure

```ini
[all]
postgresql1 ansible_host=192.168.122.236
postgresql2 ansible_host=192.168.122.233
postgresql3 ansible_host=192.168.122.206

[postgresql:vars]
postgresql_network_interface = enp1s0
postgresql_version = 17
wire_dbname = wire-server
wire_user = wire-server
# Optional: wire_pass = verysecurepassword (if not defined, auto-generated)

# All PostgreSQL nodes
[postgresql]
postgresql1
postgresql2
postgresql3

# Primary (read-write) node
[postgresql_rw]
postgresql1

# Replica (read-only) nodes
[postgresql_ro]
postgresql2
postgresql3
```

### Node Groups Explained

| Group | Purpose | Nodes | Role |
|-------|---------|-------|------|
| `postgresql` | All PostgreSQL nodes | postgresql1-3 | Base configuration |
| `postgresql_rw` | Primary nodes | postgresql1 | Read/Write operations |
| `postgresql_ro` | Replica nodes | postgresql2-3 | Read-only operations |

### Configuration Variables

| Variable | Default | Description | Required |
|----------|---------|-------------|----------|
| `postgresql_network_interface` | `enp1s0` | Network interface for cluster communication | No |
| `postgresql_version` | `17` | PostgreSQL major version | No |
| `wire_dbname` | `wire-server` | Database name for Wire application | Yes |
| `wire_user` | `wire-server` | Database user for Wire application | Yes |
| `wire_pass` | auto-generated | Password (displayed as output of the ansible task) | No |


## Installation Process

### 🚀 Complete Installation (Fresh Deployment)

#### **Step 1: Verify Connectivity**
```bash
# Test Ansible connectivity to all nodes
ansible all -i ansible/inventory/offline/hosts.ini -m ping
```

#### **Step 2: Full Cluster Deployment**
See the [Deployment Commands Reference](#deployment-commands-reference) section for all available deployment commands.

**⏱️ Expected Duration: 10-15 minutes**

A complete deployment performs:
1. ✅ **Package Installation**: PostgreSQL 17 + repmgr + dependencies
2. ✅ **Primary Setup**: Configure primary node with repmgr database
3. ✅ **Replica Deployment**: Clone and configure replica nodes
4. ✅ **Verification**: Health checks and replication status
5. ✅ **Wire Integration**: Create Wire database and user
6. ✅ **Monitoring**: Deploy split-brain detection system

#### **Step 3: Verify Installation**
See the [Monitoring Checks](#monitoring-checks-after-installation) section for comprehensive verification procedures.

## Deployment Commands Reference

### 🎯 Main Commands

```bash
# Complete fresh deployment
ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/postgresql-deploy.yml

# Clean previous deployment
# Only cleans the messy configurations the data remains intact
ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/postgresql-deploy.yml --tag cleanup

# Deploy without the cleanup process
ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/postgresql-deploy.yml --skip-tags "cleanup"
```

### 🏷️ Tag-Based Deployments

| Tag | Description | Example |
|-----|-------------|---------|
| `cleanup` | Clean previous deployment state | `--tags "cleanup"` |
| `install` | Install PostgreSQL packages only | `--tags "install"` |
| `primary` | Deploy primary node only | `--tags "primary"` |
| `replica` | Deploy replica nodes only | `--tags "replica"` |
| `verify` | Verify HA setup only | `--tags "verify"` |
| `wire-setup` | Wire database setup only | `--tags "wire-setup"` |
| `monitoring` | Deploy cluster monitoring only | `--tags "monitoring"` |

## Monitoring Checks After Installation

### 🛡️ Key Verification Commands

```bash
# 1. Cluster status (primary command)
sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf cluster show

# 2. Service status
sudo systemctl status postgresql@17-main repmgrd@17-main detect-rogue-primary.timer

# 3. Replication status (run on primary)
sudo -u postgres psql -c "SELECT application_name, client_addr, state FROM pg_stat_replication;"

# 4. Check split-brain detector logs
sudo journalctl -u detect-rogue-primary.service --since "10m ago"

# 5. Check fence events
sudo tail -n 20 -f /var/log/postgresql/fence_events.log

# 6. Manual promotion (rare emergency case)
sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf standby promote
```

## How It Confirms a Reliable System

### 🛡️ Reliability Features
- **Split-Brain Prevention**: 30-second monitoring with automatic protection
- **Automatic Failover**: < 30 seconds detection and promotion
- **Data Consistency**: Streaming replication with timeline management
- **Self-Healing**: Event-driven recovery and service management

### 🎯 Quick Health Check
```bash
sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf cluster show
sudo systemctl status detect-rogue-primary.timer
sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;"
```

**Expected**: One primary "* running", all replicas "running", timer "active (waiting)"

## Configuration Options

### 🔧 repmgr Configuration
- **Node Priority**: `priority` Determines promotion order during failover (higher values preferred)
- **Monitoring Interval**: `monitor_interval_secs` (default: 2 seconds)
- **Reconnect Settings**: `reconnect_attempts` (default: 5), `reconnect_interval` (default: 5 seconds)

*Configuration file: [`ansible/inventory/offline/group_vars/postgresql/postgresql.yml`](../ansible/inventory/offline/group_vars/postgresql/postgresql.yml)*

**Node Configuration:**
```yaml
repmgr_node_config:
  postgresql1:  # Primary node
    node_id: 1
    priority: 150
    role: primary
  postgresql2:  # First standby
    node_id: 2
    priority: 100
    role: standby
  postgresql3:  # Second standby
    node_id: 3
    priority: 50
    role: standby
```

*See [repmgr configuration reference](https://repmgr.org/docs/current/configuration-file.html) for complete options.*

### 🛡️ Failover Validation
- **Quorum**: Minimum 2 visible nodes for 3+ node clusters
- **Lag Threshold**: `LAG_CAP` environment variable (default: 64MB)
- **Connectivity**: WAL receiver activity validation

## Node Recovery Operations

### 🔄 Standard Node Rejoin

```bash
# Compatible data rejoin
sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf node rejoin -d repmgr -h <primary-ip> -U repmgr --verbose

# Timeline divergence rejoin
sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf node rejoin -d repmgr -h <primary-ip> -U repmgr --force-rewind --verbose
```

### 🚨 Emergency Recovery

Usually the recovery time is very fast on postgres cluster level (30 seconds to a minute) but for the application it might take from 1 minute to 2 minutes. The reason is postgres-endpoint-manager cronjob runs every 2 minutes to check and update the postgresql endpoints if necessary.

**Complete Cluster Failure (All Nodes Down):**

When all PostgreSQL nodes fail simultaneously (power outage, network failure, etc.), follow this recovery procedure:

**Step 1: Identify the Most Recent Primary**
On each node, check the data consistency and timeline:
```bash
# Check control data on each node
sudo -u postgres /usr/lib/postgresql/17/bin/pg_controldata /var/lib/postgresql/17/main | grep -E "Latest checkpoint location|TimeLineID|Time of latest checkpoint|Database system identifier"

# Compare LSN (Log Sequence Number) - highest LSN has most recent data
```

**Step 2: Start the Most Recent Primary**
Choose the node with the highest LSN/most recent checkpoint:
```bash
# Start PostgreSQL service on the chosen node
sudo systemctl start postgresql@17-main

# Register as new primary (removes old cluster metadata)
sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf primary register --force

# Start repmgrd daemon and split-brain detection
sudo systemctl start repmgrd@17-main
sudo systemctl start detect-rogue-primary.timer
```

**Step 3: Rejoin Other Nodes as Standby**
For each remaining node:
```bash
# Start PostgreSQL service
sudo systemctl start postgresql@17-main

# Force rejoin as standby (handles timeline divergence)
sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf node rejoin -d repmgr -h <new-primary-ip> -U repmgr --force-rewind --verbose

# Start repmgrd daemon and split-brain detection after successful rejoin
sudo systemctl start repmgrd@17-main
sudo systemctl start detect-rogue-primary.timer
```

**Step 4: Verify Cluster Recovery**
```bash
# Check cluster status
sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf cluster show

# Verify replication
sudo -u postgres psql -c "SELECT application_name, client_addr, state FROM pg_stat_replication;"

# Check all services are running
sudo systemctl status postgresql@17-main repmgrd@17-main detect-rogue-primary.timer
```

**⚠️ Important Notes:**
- **Data Loss Risk**: If nodes have divergent data, some transactions may be lost
- **Timeline Handling**: `--force-rewind` automatically handles timeline divergence
- **Service Order**: Always start PostgreSQL before attempting repmgr operations
- **Backup Recovery**: If all nodes are corrupted, restore from backup before following this procedure

**Expected Recovery Time**: 5-15 minutes depending on data size and number of nodes

**Bring back the old primary as standby (Split-Brain Resolution):**
- Get the current primary node ip with `sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf cluster show` on a active node.
- `ssh` into the old primary
- Unmask service and rejoin the cluster as standby with this command: `sudo systemctl unmask postgresql@17-main.service && sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf node rejoin -d repmgr -h <primary-ip> -U repmgr --force-rewind --verbose`
- Service auto-starts in standby mode and will start following the new primary when the rejoin succeeds and if it fails the node might join the cluster as standalone standby.
- Check the cluster status `sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf cluster show` to make sure the node joins the cluster properly and the upstream is the new primary.
- If the upstream of the re-joined node is empty that means the re-join failed partially, please rerun the above procedure by
- masking and stopping postgresql first: `sudo systemctl mask postgresql@17-main && sudo systemctl stop postgresql@17-main`
- Run the unmask and rejoin command. That should be it.

### 🔧 OS Upgrades and Maintenance Operations

**Behavior During OS Upgrades**: PostgreSQL HA cluster handles OS-level maintenance (firmware updates, kernel upgrades, reboots) gracefully with automatic failover and recovery.

#### **Planned Maintenance (Single Node)**
1. **Pre-Reboot**:
   - **For major OS updates**: Disable repmgrd and split-brain detection to prevent conflicts:
     ```bash
     sudo systemctl stop repmgrd@17-main && sudo systemctl disable repmgrd@17-main
     sudo systemctl stop detect-rogue-primary.timer && sudo systemctl disable detect-rogue-primary.timer
     ```
   - **For routine reboots**: No manual intervention required, repmgr automatically detects node unavailability
2. **During Reboot**:
   - If **replica node**: Cluster continues normally with remaining nodes
   - If **primary node**: Automatic failover occurs (~10-30s), promotes best replica
3. **Post-Reboot**:
   - **After major OS updates**: Manually rejoin cluster in standby mode:
     ```bash
     # Start PostgreSQL service
     sudo systemctl start postgresql@17-main
     # Manually rejoin as standby
     sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf node rejoin -d repmgr -h <primary-ip> -U repmgr --verbose
     # Re-enable services after successful rejoin
     sudo systemctl enable repmgrd@17-main && sudo systemctl start repmgrd@17-main
     sudo systemctl enable detect-rogue-primary.timer && sudo systemctl start detect-rogue-primary.timer
     ```
   - **After routine reboots**: Node automatically rejoins as standby, catches up via WAL streaming
4. **Service Status**: PostgreSQL and repmgrd services auto-start via systemd (enabled by default for routine maintenance)

#### **Rolling Upgrades (Multiple Nodes)**
**Recommended Sequence for Major OS Updates**:
1. **Disable repmgrd and split-brain detection on all nodes**:
   ```bash
   sudo systemctl stop repmgrd@17-main && sudo systemctl disable repmgrd@17-main
   sudo systemctl stop detect-rogue-primary.timer && sudo systemctl disable detect-rogue-primary.timer
   ```
2. Upgrade replica nodes first (postgresql2, postgresql3)
3. Manually rejoin each replica as standby after upgrade
4. Upgrade primary node last (postgresql1) - automatic failover will occur
5. Manually rejoin former primary as standby
6. **Re-enable all services on all nodes**:
   ```bash
   sudo systemctl enable repmgrd@17-main && sudo systemctl start repmgrd@17-main
   sudo systemctl enable detect-rogue-primary.timer && sudo systemctl start detect-rogue-primary.timer
   ```
7. Monitor cluster status between each step: `sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf cluster show`

#### **Manual Verification Steps**
After each node reboot, verify:
```bash
# Check cluster status
sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf cluster show

# Verify services are running
sudo systemctl status postgresql@17-main repmgrd@17-main detect-rogue-primary.timer

# Check replication status (on current primary)
sudo -u postgres psql -c "SELECT application_name, client_addr, state FROM pg_stat_replication;"
```

#### **Troubleshooting Failed Auto-Recovery**
If a node doesn't rejoin automatically after reboot:

**For Major OS Updates (repmgrd and split-brain detection were disabled):**
1. **Start PostgreSQL service**: `sudo systemctl start postgresql@17-main`
2. **Manual rejoin as standby**:
   ```bash
   sudo systemctl unmask postgresql@17-main.service && sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf node rejoin -d repmgr -h <primary-ip> -U repmgr --verbose
   ```
3. **Re-enable all services**:
   ```bash
   sudo systemctl enable repmgrd@17-main && sudo systemctl start repmgrd@17-main
   sudo systemctl enable detect-rogue-primary.timer && sudo systemctl start detect-rogue-primary.timer
   ```
4. **Check logs**: `sudo journalctl -u postgresql@17-main -u repmgrd@17-main --since "10m ago"`

**For Routine Reboots (automatic recovery expected):**
1. **Check service status**: `sudo systemctl status postgresql@17-main repmgrd@17-main detect-rogue-primary.timer`
2. **Manual start if needed**: `sudo systemctl start postgresql@17-main repmgrd@17-main detect-rogue-primary.timer`
3. **Force rejoin if timeline diverged**:
   ```bash
   sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf node rejoin -d repmgr -h <primary-ip> -U repmgr --force-rewind --verbose
   ```
4. **Check logs**: `sudo journalctl -u postgresql@17-main -u repmgrd@17-main --since "10m ago"`

#### **Client Application Impact**
- **During failover**: Brief connection interruption (10-30s), applications should implement retry logic
- **Kubernetes environments**: postgres-endpoint-manager updates service endpoints within 2 minutes
- **Multiple primaries**: If multiple primaries are detected by the postgres-endpoint-manager, it will skip the endpoint update unless it gets resolved in the postgres cluster and will keep the last know good state. Check the cronjob pods log for details.

**Best Practice**: Schedule maintenance during low-traffic periods and monitor cluster health throughout the process.

**⚠️ Critical Note**: The split-brain detection timer (`detect-rogue-primary.timer`) runs independently of `repmgrd` and will continue to mask PostgreSQL services if it detects split-brain scenarios. Always disable it during major OS updates to prevent conflicts with manual cluster management.

## Wire Server Database Setup

The [`postgresql-wire-setup.yml`](../ansible/postgresql-playbooks/postgresql-wire-setup.yml) playbook creates the Wire server database and user account with **automatic Kubernetes secret management** - eliminating manual password handling.

### 🔐 Kubernetes Secret-Based Password Management

**How It Works:**
1. ✅ **Checks for existing K8s secret** `wire-postgresql-external-secret` in the cluster
2. ✅ **If exists**: Retrieves password from secret and uses it
3. ✅ **If not exists**: Generates strong 32-character random password and creates secret
4. ✅ **Creates/updates PostgreSQL user** with the password
5. ✅ **Stores credentials** in Kubernetes for wire-server to use


### 📋 Running the Setup Playbook

```bash
# Run the wire-server database setup
ansible-playbook ansible/postgresql-playbooks/postgresql-wire-setup.yml \
  -i ansible/inventory/offline/99-static
```

### 🔧 Using Password in Wire-Server Configuration

The Ansible playbook automatically creates the Kubernetes secret `wire-postgresql-external-secret` with the database password. Wire-server components can reference this password in two ways:


#### **Option 1: Password Insertion into Helm Values**

For deployments that require passwords in `secrets.yaml`:

**Step 1: Retrieve the password from Kubernetes**
```bash
# Export password to environment variable
PG_PASSWORD=$(kubectl get secret wire-postgresql-external-secret \
  -n default \
  -o jsonpath='{.data.password}' | base64 --decode)

# Display the password (verify it's retrieved correctly)
echo "Password: ${PG_PASSWORD}"
```

**Step 2: Edit secrets.yaml manually**

Open `values/wire-server/secrets.yaml` in your editor and insert the password:

```yaml
brig:
  secrets:
    pgPassword: "paste-your-actual-password-here"
    # ... other secrets ...

galley:
  secrets:
    pgPassword: "paste-your-actual-password-here"
    # ... other secrets ...
```


#### **Option 2: Use Helm --set Flag**

For quick deployments or testing, override passwords during helm installation:

```bash
# Retrieve password
PG_PASSWORD=$(kubectl get secret wire-postgresql-external-secret \
  -n default \
  -o jsonpath='{.data.password}' | base64 --decode)

# Install/upgrade with password override
helm upgrade --install wire-server ./charts/wire-server \
  --namespace default \
  -f values/wire-server/values.yaml \
  -f values/wire-server/secrets.yaml \
  --set brig.secrets.pgPassword="${PG_PASSWORD}" \
  --set galley.secrets.pgPassword="${PG_PASSWORD}"
```

**Note:** This method exposes passwords in shell history. Use with caution.

---

**🔐 Important Notes:**
- Do NOT manually set `wire_pass` in Ansible inventory - the playbook automatically manages passwords via Kubernetes secrets
- The Kubernetes secret is the **source of truth** for the database password
- After Ansible playbook completion, always retrieve passwords from K8s rather than regenerating them

## Kubernetes Integration

This PostgreSQL HA cluster runs **independently outside Kubernetes** (on bare metal or VMs). For Kubernetes environments, the separate **postgres-endpoint-manager** component keeps PostgreSQL endpoints up to date:

- **Purpose**: Monitors PostgreSQL cluster state and updates Kubernetes service endpoints during failover
- **Repository**: [https://github.com/wireapp/postgres-endpoint-manager](https://github.com/wireapp/postgres-endpoint-manager)
- **Architecture**: Runs as a separate service that watches pg cluster events and updates Kubernetes services
- **Benefit**: Provides seamless failover transparency to containerized applications without cluster modification

The PostgreSQL cluster operates independently, while the endpoint manager acts as an external observer that ensures Kubernetes applications always connect to the current primary node.
