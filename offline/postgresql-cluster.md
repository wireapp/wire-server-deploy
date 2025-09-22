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

**Recovery:** Event-driven fence script automatically unmasks services during successful rejoins

### 🔄 Self-Healing Capabilities

| Scenario | Detection | Recovery Time | Data Loss |
|----------|-----------|---------------|-----------|
| Primary Failure | 5-30 seconds | < 30 seconds | None |
| Network Partition | 30-60 seconds | Automatic | None |
| Node Recovery | Immediate | < 2 minutes | None |

**Primary Failure**: repmgrd monitors connectivity (2s intervals), confirms failure after 6 attempts (12s), validates quorum (≥2 nodes for 3+ clusters), selects best replica by priority/lag, promotes automatically with zero data loss.

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
- **Monitoring Interval**: `repmgr_monitor_interval` (default: 2 seconds)
- **Reconnect Settings**: `repmgr_reconnect_attempts` (default: 6), `repmgr_reconnect_interval` (default: 5 seconds)

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

**Complete Cluster Failure:**
1. Find node with most recent data: `sudo -u postgres /usr/lib/postgresql/17/bin/pg_controldata /var/lib/postgresql/17/main | grep -E "Latest checkpoint location|TimeLineID|Time of latest checkpoint"`
2. Register as primary: `sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf primary register --force`
3. Rejoin other nodes with `--force-rewind`

**Split-Brain Resolution:**
- Unmask service: `sudo systemctl unmask postgresql@17-main.service`
- Rejoin to correct primary with `sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf node rejoin -d repmgr -h <primary-ip> -U repmgr --force-rewind --verbose` (run the command just after the unmasking, the repmgr can mask it again if the rejoin command is not running in quick succession of the unmask command)
- Service auto-starts in standby mode and will start following the new primary when the rejoin succeeds and if it fails the node might join the cluster as standalone standby.
- Check the cluster status `sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf cluster show` to make sure the node joins the cluster properly.
- The newly joined node is not following the new primary, then:
- unmask/stop postgresql and re-run the rejoin command from above.

## Wire Server Database Setup

The [`postgresql-wire-setup.yml`](../ansible/postgresql-playbooks/postgresql-wire-setup.yml) playbook creates the Wire server database and user account.

**Usage:** See the [Deployment Commands Reference](#deployment-commands-reference) section for all Wire setup commands.

**Important:** Generated password is displayed in Ansible output task `Display PostgreSQL setup completion` - save it securely for Wire server configuration.

## Kubernetes Integration

This PostgreSQL HA cluster runs **independently outside Kubernetes** (on bare metal or VMs). For Kubernetes environments, the separate **postgres-endpoint-manager** component keeps PostgreSQL endpoints up to date:

- **Purpose**: Monitors PostgreSQL cluster state and updates Kubernetes service endpoints during failover
- **Repository**: [https://github.com/wireapp/postgres-endpoint-manager](https://github.com/wireapp/postgres-endpoint-manager)
- **Architecture**: Runs as a separate service that watches pg cluster events and updates Kubernetes services
- **Benefit**: Provides seamless failover transparency to containerized applications without cluster modification

The PostgreSQL cluster operates independently, while the endpoint manager acts as an external observer that ensures Kubernetes applications always connect to the current primary node.
