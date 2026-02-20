# PostgreSQL High Availability Cluster Deployment Guide

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Key Concepts](#key-concepts)
- [Minimum System Requirements](#minimum-system-requirements)
- [High Availability Features](#high-availability-features)
- [Inventory Definition](#inventory-definition)
- [Installation Process](#installation-process)
- [Package Upgrades and Binary Updates](#package-upgrades-and-binary-updates)
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
- **PostgreSQL**: 17.7-3 (latest stable with enhanced replication features)
- **postgres_exporter**: 0.18.1 (Prometheus metrics exporter for PostgreSQL monitoring)
- **repmgr**: 5.5.0 (production-ready cluster management with advanced failover) ([docs](https://repmgr.org/docs/current/))
- **Ubuntu/Debian**: 20.04+ / 11+ (tested platforms for production deployment)

## Minimum System Requirements

Based on the PostgreSQL configuration template, the deployment is optimized for resource-constrained environments:

**Memory Requirements:**
- **RAM**: 2GB minimum per node (based on configuration tuning)
  - `shared_buffers = 512MB` (25% of total RAM)
  - `effective_cache_size = 1GB` (50% of total RAM estimate)
  - `maintenance_work_mem = 64MB`
  - `work_mem = 512kB` per connection (with `max_connections = 100`)

**CPU Requirements:**
- **Cores**: 2 CPU cores minimum
  - `max_parallel_workers_per_gather = 0` (parallel queries disabled)
  - `max_parallel_workers = 4`
  - `max_worker_processes = 8` (for repmgr operations and parallel workers)

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

**Note**: Configuration supports up to 100 concurrent connections. For production workloads with higher loads, scale up resources accordingly.

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

| Scenario | Detection Time | Promotion/Recovery Time | Total Time | Data Loss |
|----------|----------------|------------------------|------------|-----------|
| Primary Failure | 30-40 seconds | 10-20 seconds | **40-60 seconds** | None |
| Network Partition | 30-120 seconds | Automatic | Varies | None |
| Node Rejoin | Immediate | 15-30 seconds (rejoin) + WAL catch-up | **< 2 minutes*** | None |

\* WAL catch-up time depends on how long the node was down. For short outages (< 5 min), typically < 2 minutes. For longer outages, may require full basebackup if WAL segments were recycled (see `wal_keep_size = 2GB` configuration).

**Primary Failure Details**:
- **Detection**: repmgrd monitors connectivity every 2s
- **Failure confirmation**: 6 reconnection attempts × 5s = 30s
- **Total detection time**: ~32-40s (2s monitoring + 30s reconnection attempts)
- **Promotion process**: Validates quorum (≥2 nodes visible), checks WAL lag, selects best replica by priority
- **Promotion time**: ~10-20 seconds
- **Total failover time**: ~40-60 seconds from primary failure to new primary accepting writes

**Network Partition Details**:
- **Detection**: 30s systemd timer triggers split-brain detection
- **Protection**: Cross-node verification identifies conflicting primaries
- **Isolation**: Masks and stops PostgreSQL service on isolated primary
- **Auto-recovery**: When network restores, fence scripts unmask services during successful rejoin
- **Timeline sync**: Uses pg_rewind if timelines diverged during partition

**Node Recovery Details**:
- **Rejoin process**: 15-30 seconds to execute `repmgr node rejoin` command
- **WAL streaming**: Begins immediately after rejoin
- **Catch-up time**:
  - Short outage (< 5 min): Typically < 2 minutes via WAL streaming
  - Medium outage (5-30 min): 2-10 minutes depending on write load
  - Long outage (> 30 min): If WAL segments recycled, requires full clone (see Manual Standby Clone section)
- **Auto-start**: PostgreSQL starts in standby mode automatically via systemd

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
repmgr_node_config:
  postgresql1:  # Maps to postgresql_rw group
    node_id: 1
    priority: 150
    role: primary
  postgresql2:  # Maps to first postgresql_ro
    node_id: 2
    priority: 100
    role: standby
  postgresql3:  # Maps to second postgresql_ro
    node_id: 3
    priority: 50
    role: standby

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

### Group Variables Configuration

PostgreSQL configuration variables are defined in `ansible/inventory/offline/group_vars/postgresql/postgresql.yml`:

```yaml
# PostgreSQL configuration for all PostgreSQL nodes
postgresql_version: 17
postgresql_data_dir: /var/lib/postgresql/{{ postgresql_version }}/main
postgresql_conf_dir: /etc/postgresql/{{ postgresql_version }}/main

# wire-server database configuration
wire_dbname: wire-server
wire_user: wire-server
wire_namespace: default  # Kubernetes namespace for secret storage

# repmgr HA configuration
repmgr_user: repmgr
repmgr_database: repmgr
repmgr_secret_name: "repmgr-postgresql-secret"
repmgr_namespace: "{{ wire_namespace | default('default') }}"

# Kubernetes Secret configuration for wire-server PostgreSQL user
wire_pg_secret_name: "wire-postgresql-external-secret"

# Note: repmgr_password and wire_pass are NOT defined here
# They are dynamically set by postgresql-secrets.yml playbook
# Passwords are fetched from K8s secrets or auto-generated during deployment
```

**Network-specific variables** (like `postgresql_network_interface`) should be set in your inventory file's `[postgresql:vars]` section if they differ from defaults.

### Node Groups Explained

| Group | Purpose | Nodes | Role |
|-------|---------|-------|------|
| `postgresql` | All PostgreSQL nodes | postgresql1-3 | Base configuration |
| `postgresql_rw` | Primary nodes | postgresql1 | Read/Write operations |
| `postgresql_ro` | Replica nodes | postgresql2-3 | Read-only operations |

### Configuration Variables

All configuration variables are defined in `group_vars/postgresql/postgresql.yml`:

| Variable | Default | Description | Location | Required |
|----------|---------|-------------|----------|----------|
| `postgresql_version` | `17` | PostgreSQL major version | group_vars | No |
| `postgresql_network_interface` | `enp1s0` | Network interface for cluster communication | inventory vars | No |
| `wire_dbname` | `wire-server` | Database name for Wire application | group_vars | Yes |
| `wire_user` | `wire-server` | Database user for Wire application | group_vars | Yes |
| `wire_namespace` | `default` | Kubernetes namespace for secrets | group_vars | Yes |
| `wire_pass` | auto-generated | Password from K8s secret or auto-generated | dynamic | No |
| `repmgr_user` | `repmgr` | Repmgr HA user | group_vars | Yes |
| `repmgr_database` | `repmgr` | Repmgr database name | group_vars | Yes |
| `repmgr_password` | auto-generated | Password from K8s secret or auto-generated | dynamic | No |


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
1. ✅ **Backup**: Create safety backup of existing data to assethost (skipped for fresh installs)
2. ✅ **Cleanup**: Reset repmgr HA cluster configuration (preserves PostgreSQL data)
3. ✅ **Package Installation**: PostgreSQL 17 + repmgr + postgres_exporter + dependencies
4. ✅ **Primary Setup**: Configure primary node with repmgr database
5. ✅ **Replica Deployment**: Clone and configure replica nodes
6. ✅ **Verification**: Health checks and replication status
7. ✅ **Wire Integration**: Create Wire database and user
8. ✅ **Monitoring**: Deploy split-brain detection system
9. ✅ **Metrics Exporter**: Deploy postgres_exporter for Prometheus monitoring

#### **Step 3: Verify Installation**
See the [Monitoring Checks](#monitoring-checks-after-installation) section for comprehensive verification procedures.

## Package Upgrades and Binary Updates

### 🔄 Upgrading PostgreSQL Packages

The installation playbook automatically detects version mismatches and performs upgrades when newer packages are available in the configuration.

**Version-Aware Detection:**
- Compares installed package versions with configured versions in `group_vars/postgresql/postgresql.yml`
- Triggers upgrades automatically when versions don't match (e.g., 17.5-1 → 17.7-3)
- Handles interdependent packages atomically to prevent dependency conflicts

**Upgrade Process:**
```bash
# Full redeployment with version upgrades
ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/postgresql-deploy.yml
```

The playbook will:
1. ✅ Detect version differences in installed packages
2. ✅ Download and install updated packages atomically
3. ✅ Preserve existing data and replication configuration
4. ✅ Verify successful installation

**Verification:**
```bash
# Check installed PostgreSQL version
dpkg -l | grep postgresql-17

# Expected output shows new version (e.g., 17.7-3.pgdg22.04+1)
```

### 🛡️ Automatic Backup Before Cleanup

When redeploying or cleaning existing PostgreSQL installations, automatic backups protect your data.

**Backup Features:**
- **Parallel backups** from all nodes (primary + replicas) for faster completion
- **Automatic detection** of node roles (primary/replica)
- **Centralized storage** on assethost with timestamp-based directories
- **Graceful skip** if assethost is not defined in inventory

**Backup Location:**
```bash
# Backups stored on assethost at:
/var/backups/postgresql/<timestamp>/

# Example:
/var/backups/postgresql/20251208T152506/
  - postgresql1_primary_full.sql.gz
  - postgresql2_replica_full.sql.gz
  - postgresql3_replica_full.sql.gz
```

**Assethost Configuration:**
Define assethost in your inventory to enable automatic backups:
```ini
[all]
assethost ansible_host=192.168.122.10
```

**Backup Process:**
1. Detects existing PostgreSQL installation
2. Creates backups on all nodes in parallel
3. Transfers backups to assethost via Ansible file transfer
4. Displays backup summary with restore instructions
5. Provides 10-second safety pause before proceeding with cleanup

**Restore Example:**
```bash
# List available backups
ssh assethost "ls -lh /var/backups/postgresql/20251208T152506/"

# Restore from primary backup
scp assethost:/var/backups/postgresql/20251208T152506/postgresql1_primary_full.sql.gz /tmp/
gunzip -c /tmp/postgresql1_primary_full.sql.gz | sudo -u postgres psql postgres
```

**Note:** Backups are only created when cleaning existing deployments. Fresh installations skip backup automatically.

## Deployment Commands Reference

### 🎯 Main Commands

```bash
# Complete fresh deployment (recommended)
ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/postgresql-deploy.yml

# Deploy PostgreSQL cluster (secrets + primary + replica + wire-setup + monitoring)
ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/postgresql-deploy.yml --tags postgresql

# Skip backup (not recommended - only use for fresh installs)
ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/postgresql-deploy.yml --skip-tags backup

# Deploy without cleanup (preserves existing data and configuration)
ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/postgresql-deploy.yml --skip-tags cleanup

# Verify existing cluster health
ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/postgresql-deploy.yml --tags verify
```

### 🏷️ Tag Reference

| Tag | What Runs | Use Case |
|-----|-----------|----------|
| _(none)_ | Full deployment | **Recommended for fresh deployment** |
| `postgresql` | Secrets + Primary + Replica + Wire-setup + Monitoring + Metrics | Deploy/redeploy complete PostgreSQL cluster |
| `backup` | Backup only | Create backup of all nodes to assethost |
| `verify` | Verification checks only | Check cluster health without making changes |
| `cleanup` | Cleanup only | For selective cleanup (use with `--skip-tags` to preserve data) |
| `metrics` | Metrics exporter only | Deploy/redeploy postgres_exporter for monitoring |

### 📋 Deployment Pipeline

The deployment follows this strict order:

```
1. backup           → Create safety backup to assethost (skipped for fresh installs)
2. cleanup          → Reset repmgr HA cluster configuration (preserves PostgreSQL data)
3. install          → Install PostgreSQL packages
4. secrets          → Fetch/create passwords in K8s
5. primary          → Deploy primary (read-write) node
6. replica          → Deploy replica (read-only) nodes
7. verify           → Verify HA cluster health
8. wire-setup       → Create wire-server database and user
9. monitoring       → Deploys a split-brain detection system that automatically fences isolated primary nodes to prevent data corruption
10. metrics         → Deploy postgres_exporter for Prometheus monitoring (PostgreSQL 17 metrics including checkpoint stats)
```

**Important**: Steps 4-10 have dependencies and must run in order. Backup (step 1) and cleanup (step 2) run first to prepare the environment. The `postgresql` tag ensures all required steps run together.

### 🔐 Password Management

PostgreSQL passwords are automatically managed via Kubernetes Secrets:

- **repmgr password**: `repmgr-postgresql-secret` (for HA cluster management)
- **wire-server password**: `wire-postgresql-external-secret` (for application database)

**Behavior**:
- First deployment: Passwords are auto-generated (32-character random strings)
- Subsequent deployments: Existing passwords are retrieved from K8s secrets

**Manual password access**:
```bash
# View repmgr password
kubectl get secret repmgr-postgresql-secret -n default -o jsonpath='{.data.password}' | base64 --decode

# View wire-server password
kubectl get secret wire-postgresql-external-secret -n default -o jsonpath='{.data.password}' | base64 --decode
```

**Note**: No hardcoded passwords exist in inventory files. All credentials are securely managed in Kubernetes.

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

### 🔄 Standard Node Rejoin (Existing Node Recovery)

When a node that was previously part of the cluster needs to rejoin:

```bash
# Compatible data rejoin (when timelines match)
sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf node rejoin -d repmgr -h <primary-ip> -U repmgr --verbose

# Timeline divergence rejoin (when node data diverged from primary)
sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf node rejoin -d repmgr -h <primary-ip> -U repmgr --force-rewind --verbose
```

**When to use each**:
- **Without `--force-rewind`**: Node was shut down cleanly, no timeline divergence
- **With `--force-rewind`**: Node was promoted/isolated, or data diverged from current primary

### 🆕 Manual Standby Clone and Registration (New Node Setup)

Note: You can always run the ansible playbook to reset the HA cluster configuration. It will NOT delete the existing PostgreSQL Wire database or any data - it only resets repmgr cluster state to prepare for redeployment.

When you need to manually clone and register a standby from scratch (corrupted data, new node, or complete rebuild):

**Step 1: Prepare the Node**
```bash
# Stop services if running
sudo systemctl stop repmgrd@17-main
sudo systemctl stop detect-rogue-primary.timer

# Unmask and stop PostgreSQL (in case it was masked by split-brain detection)
sudo systemctl unmask postgresql@17-main
sudo systemctl stop postgresql@17-main

# Remove existing data directory
sudo rm -rf /var/lib/postgresql/17/main/*

# Ensure clean directory with correct permissions
sudo mkdir -p /var/lib/postgresql/17/main
sudo chown -R postgres:postgres /var/lib/postgresql/17/main
sudo chmod 700 /var/lib/postgresql/17/main
```

**Step 2: Clone from Primary**
```bash
# Clone replica data from primary
sudo -u postgres repmgr -h <primary-ip> -U repmgr -d repmgr \
  -f /etc/repmgr/17-main/repmgr.conf \
  standby clone --force

# Expected output:
# INFO: connecting to source node
# NOTICE: standby clone (using pg_basebackup) complete
# NOTICE: you can now start your PostgreSQL server
```

**Step 3: Start PostgreSQL**
```bash
# Start PostgreSQL service
sudo systemctl start postgresql@17-main

# Verify it's running in standby mode
sudo -u postgres psql -c "SELECT pg_is_in_recovery();"
# Should return: t (true)
```

**Step 4: Register Standby with Cluster**
```bash
# Register the standby with repmgr
sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf \
  standby register --force

# Expected output:
# INFO: connecting to local node "postgresql2" (ID: 2)
# INFO: connecting to primary database
# INFO: standby registration complete
# NOTICE: standby node "postgresql2" (ID: 2) successfully registered
```

**Step 5: Start repmgrd and Monitoring**
```bash
# Start repmgr daemon
sudo systemctl start repmgrd@17-main

# Start split-brain detection
sudo systemctl start detect-rogue-primary.timer

# Verify services are running
sudo systemctl status postgresql@17-main repmgrd@17-main detect-rogue-primary.timer
```

**Step 6: Verify Cluster Status**
```bash
# Check cluster status
sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf cluster show

# Expected output:
#  ID | Name         | Role    | Status    | Upstream     | Priority
# ----+--------------+---------+-----------+--------------+----------
#  1  | postgresql1  | primary | * running |              | 150
#  2  | postgresql2  | standby |   running | postgresql1  | 100
#  3  | postgresql3  | standby |   running | postgresql1  | 50

# Verify replication on primary
sudo -u postgres psql -c "SELECT application_name, client_addr, state FROM pg_stat_replication;"
```

**Common Issues**:
- **Authentication fails**: Check repmgr password matches K8s secret
- **Clone hangs**: Verify network connectivity and pg_hba.conf allows replication
- **Registration fails**: Ensure primary is accessible and repmgr database exists
- **Service won't start**: Check PostgreSQL logs: `sudo journalctl -u postgresql@17-main -n 50`

**⏱️ Expected Time**: 5-15 minutes (depends on database size)

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
# Unmask and start PostgreSQL service on the chosen node
sudo systemctl unmask postgresql@17-main
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
# Unmask and start PostgreSQL service
sudo systemctl unmask postgresql@17-main
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

#### **Understanding Maintenance Types**

**Major OS Updates** (dist-upgrade, kernel upgrades, major version changes):
- **Characteristics**: Requires significant downtime, may need manual intervention
- **Why disable repmgrd**: Prevents automatic failover during planned maintenance, avoiding race conditions between manual operations and automatic promotion
- **Why disable split-brain detection**: Prevents false positives during extended maintenance windows where services are intentionally down
- **Manual control**: Ensures you control the upgrade sequence (replicas first, primary last)

**Routine Reboots** (security patches, minor updates, hardware maintenance):
- **Characteristics**: Quick restart (< 5 minutes), services auto-start
- **Automatic handling**: repmgrd and split-brain detection continue running normally
- **Failover behavior**: If primary reboots, automatic failover occurs; node rejoins as standby after restart

#### **Planned Maintenance (Single Node)**

**For Major OS Updates** (dist-upgrade, kernel change):

1. **Pre-Maintenance**:
   ```bash
   # Disable automatic failover and split-brain detection
   sudo systemctl stop repmgrd@17-main && sudo systemctl disable repmgrd@17-main
   sudo systemctl stop detect-rogue-primary.timer && sudo systemctl disable detect-rogue-primary.timer

   # Stop PostgreSQL service
   sudo systemctl mask postgresql@17-main && sudo systemctl stop postgresql@17-main
   ```

   **Why these steps**:
   - Disabling repmgrd prevents automatic failover during your planned maintenance
   - Disabling split-brain detection prevents false split-brain alerts during extended downtime
   - Masking PostgreSQL prevents accidental auto-start during package upgrades

**For Routine Reboots** (security patches, quick restarts):

1. **Pre-Reboot**:
   - **No manual intervention required**
   - repmgr automatically detects node unavailability
   - If replica: Cluster continues with remaining nodes
   - If primary: Automatic failover promotes best replica (~40-60s)
2. **During Maintenance**:
   - Perform OS upgrade (dist-upgrade, kernel update, etc.)
   - If replica: Cluster operates normally with remaining nodes
   - If primary: You may manually promote a replica before upgrading primary

3. **Post-Maintenance**:
   ```bash
   # Start PostgreSQL service
   sudo systemctl unmask postgresql@17-main
   sudo systemctl start postgresql@17-main

   # Wait for PostgreSQL to start
   sleep 5

   # Manually rejoin as standby
   sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf \
     node rejoin -d repmgr -h <primary-ip> -U repmgr --verbose

   # Re-enable automatic failover and monitoring after successful rejoin
   sudo systemctl enable repmgrd@17-main && sudo systemctl start repmgrd@17-main
   sudo systemctl enable detect-rogue-primary.timer && sudo systemctl start detect-rogue-primary.timer
   ```

4. **Verify Recovery**:
   ```bash
   # Check cluster status
   sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf cluster show

   # Verify services
   sudo systemctl status postgresql@17-main repmgrd@17-main detect-rogue-primary.timer
   ```

**For Routine Reboots** (continuation):

2. **During Reboot**:
   - Node unavailable for ~2-5 minutes
   - Cluster continues with remaining nodes
   - Services auto-start on boot (enabled by default)

3. **Post-Reboot**:
   - Node automatically rejoins as standby
   - WAL streaming begins immediately
   - Catches up with primary (typically < 2 minutes)
   - No manual intervention required

4. **Automatic Recovery**: PostgreSQL and repmgrd services auto-start via systemd

#### **Rolling Upgrades (Multiple Nodes)**
**Recommended Sequence for Major OS Updates**:
1. **Disable repmgrd and split-brain detection on all nodes**:
   ```bash
   sudo systemctl stop repmgrd@17-main && sudo systemctl disable repmgrd@17-main
   sudo systemctl stop detect-rogue-primary.timer && sudo systemctl disable detect-rogue-primary.timer
   sudo systemctl mask postgresql@17-main && sudo systemctl stop postgresql@17-main
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

If the `wire-postgresql-external-secret` is deleted, re-run the Ansible playbook `(ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/postgresql-deploy.yml)` to recreate it and update the PostgreSQL user password. Then re-sync the password into `values/wire-server/secrets.yaml` as described in [Using Password in Wire-Server Configuration](#using-password-in-wire-server-configuration).


### 🔧 Using Password in Wire-Server Configuration

Keep the Wire server password in sync with the Kubernetes secret. Choose one of the following:

#### Automatic (preferred)
- Orchestrated by the pipeline ([bin/offline-deploy.sh](../bin/offline-deploy.sh)):
  1. `postgresql-wire-setup.yml` ensures the K8s secret `wire-postgresql-external-secret` exists.
  2. [`bin/sync-k8s-secret-to-wire-secrets.sh`](../bin/sync-k8s-secret-to-wire-secrets.sh) writes the password into `values/wire-server/secrets.yaml`.
  3. `bin/helm-operations.sh` deploys using the updated values file.

#### Manual sync
Use the generic sync script to copy the password from the K8s secret into your values file:

```bash
# Sync PostgreSQL password from K8s secret to secrets.yaml
./bin/sync-k8s-secret-to-wire-secrets.sh \
  wire-postgresql-external-secret \
  password \
  values/wire-server/secrets.yaml \
  .brig.secrets.pgPassword \
  .galley.secrets.pgPassword \
  .spar.secrets.pgPassword \
  .gundeck.secrets.pgPassword
```

#### Helm override (optional)
Skip editing files and pass the password at install/upgrade time:

```bash
# Retrieve password from Kubernetes secret
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

#### Verify
Confirm the secret and values are consistent and components can connect:

```bash
./bin/sync-k8s-secret-to-wire-server-values.sh
```

---

**🔐 Important Notes:**
- **Do NOT** manually set `wire_pass` in Ansible inventory - automatically managed via Kubernetes secrets
- **Source of Truth**: The Kubernetes secret `wire-postgresql-external-secret` is authoritative
- **Auto-Generated**: Passwords are randomly generated 32-character strings (high entropy)
- **Idempotent**: Running `sync-k8s-secret-to-wire-secrets.sh` multiple times is safe
- **CI/CD**: Password sync is automatic in offline deployment pipelines

## Kubernetes Integration

This PostgreSQL HA cluster runs **independently outside Kubernetes** (on bare metal or VMs). For Kubernetes environments, the separate **postgres-endpoint-manager** component keeps PostgreSQL endpoints up to date:

- **Purpose**: Monitors PostgreSQL cluster state and updates Kubernetes service endpoints during failover
- **Repository**: [https://github.com/wireapp/postgres-endpoint-manager](https://github.com/wireapp/postgres-endpoint-manager)
- **Architecture**: Runs as a separate service that watches pg cluster events and updates Kubernetes services
- **Benefit**: Provides seamless failover transparency to containerized applications without cluster modification

The PostgreSQL cluster operates independently, while the endpoint manager acts as an external observer that ensures Kubernetes applications always connect to the current primary node.
