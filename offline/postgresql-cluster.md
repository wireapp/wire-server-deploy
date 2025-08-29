# PostgreSQL High Availability Cluster Deployment Guide

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Key Concepts](#key-concepts)
- [High Availability Features](#high-availability-features)
- [Inventory Definition](#inventory-definition)
- [Installation Process](#installation-process)
- [Deployment Commands Reference](#deployment-commands-reference)
- [Monitoring Checks After Installation](#monitoring-checks-after-installation)
- [How It Confirms a Reliable System](#how-it-confirms-a-reliable-system)
- [Node Recovery Operations](#node-recovery-operations)
- [Wire Server Database Setup](#wire-server-database-setup)

## Architecture Overview

The PostgreSQL cluster implements a **Primary-Replica High Availability** architecture with intelligent **split-brain protection** and **automatic failover capabilities**:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   PostgreSQL1   │    │   PostgreSQL2   │    │   PostgreSQL3   │
│    (Primary)    │───▶│   (Replica)     │    │   (Replica)     │
│   Read/Write    │    │   Read-Only     │    │   Read-Only     │
│                 │    │                 │    │                 │
│ • PostgreSQL 17 │    │ • PostgreSQL 17 │    │ • PostgreSQL 17 │
│ • repmgr        │    │ • repmgr        │    │ • repmgr        │
│ • repmgrd       │    │ • repmgrd       │    │ • repmgrd       │
│ • Split-brain   │    │ • Split-brain   │    │ • Split-brain   │
│   monitoring    │    │   monitoring    │    │   monitoring    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │ Intelligent     │
                    │ • Failover      │
                    │ • Split-brain   │
                    │   Protection    │
                    │ • Self-healing  │
                    └─────────────────┘
```

### Core Components

1. **PostgreSQL 17 Cluster**: Latest stable PostgreSQL with performance improvements
2. **repmgr**: Cluster management and automatic failover orchestration
3. **Split-Brain Detection**: Intelligent monitoring prevents data corruption scenarios
4. **Event-Driven Recovery**: Automatic handling of cluster state changes
5. **Wire-Server Integration**: Pre-configured for Wire backend services

## Key Concepts

### Technology Stack
- **PostgreSQL 17**: Latest stable version with streaming replication
- **repmgr/repmgrd**: Cluster management and automatic failover
- **Split-Brain Detection**: Intelligent monitoring prevents data corruption
- **Wire Integration**: Pre-configured database setup

### High Availability Features
- **Automatic Failover**: < 30 seconds detection and promotion
- **Split-Brain Protection**: Monitors and prevents multiple primaries
- **Self-Healing**: Event-driven recovery and service management
- **Zero Data Loss**: Physical replication slots and timeline management

## High Availability Features

### 🎯 Automatic Failover
- **Detection**: repmgrd monitors primary connectivity with configurable timeouts
- **Promotion**: Promotes replica with most recent data automatically
- **Rewiring**: Remaining replicas connect to new primary automatically

### 🛡️ Split-Brain Protection

**Detection Logic:**
1. Check: Am I an isolated primary? (no active replicas)
2. Query other nodes: Is another node also primary?
3. If conflict detected → Mask and stop PostgreSQL service

**Recovery:** Event-driven fence script automatically unmasks services during successful rejoins

### 🔄 Self-Healing Capabilities

| Scenario | Detection | Recovery Time | Data Loss |
|----------|-----------|---------------|-----------|
| Primary Failure | 5-30 seconds | < 30 seconds | None |
| Network Partition | 30-60 seconds | Automatic | None |
| Node Recovery | Immediate | < 2 minutes | None |

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
| `wire_pass` | auto-generated | Password (displayed after deployment) | No |

## Installation Process

### 🚀 Complete Installation (Fresh Deployment)

#### **Prerequisites**
- Ubuntu 20.04+ or Debian 11+ on all nodes
- Minimum 4GB RAM per node (8GB+ recommended)
- SSH access configured for Ansible with sudo privileges
- Network connectivity between all nodes (PostgreSQL port 5432)
- Firewall configured to allow PostgreSQL traffic between nodes

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
ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/postgresql-playbooks/clean_exiting_setup.yml
```

### 🏷️ Tag-Based Deployments

| Tag | Description | Example |
|-----|-------------|---------|
| `monitoring` | Split-brain detection only | `--tags "monitoring"` |
| `wire-setup` | Wire database setup only | `--tags "wire-setup"` |
| `replica` | Replica configuration only | `--tags "replica"` |

```bash
# Common scenarios
ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/postgresql-deploy.yml --tags "monitoring"
ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/postgresql-deploy.yml --skip-tags "wire-setup"
```

**Note:** Replace `ansible/inventory/offline/hosts.ini` with your actual inventory path.

## Monitoring Checks After Installation

### 🛡️ Key Verification Commands

```bash
# 1. Cluster status (primary command)
sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf cluster show

# 2. Service status
systemctl status postgresql@17-main repmgrd@17-main detect-rouge-primary.timer

# 3. Replication status (run on primary)
sudo -u postgres psql -c "SELECT application_name, client_addr, state FROM pg_stat_replication;"
```

### 📊 Monitoring System Details

The deployment includes automated split-brain detection:

- **Timer**: Every 30 seconds via systemd timer
- **Script**: `/usr/local/bin/detect_rouge_primary.sh`
- **Fence Script**: `/usr/local/bin/simple_fence.sh` (handles repmgr events)
- **Logs**: `journalctl -u detect-rouge-primary.service`

**What it does:**
1. Detects isolated primary (no active replicas)
2. Queries other nodes for primary status conflicts
3. Masks and stops PostgreSQL if split-brain detected
4. Auto-unmasks services during successful rejoins

## How It Confirms a Reliable System

### 🛡️ Reliability Features

- **Split-Brain Prevention**: 30-second monitoring with automatic protection
- **Automatic Failover**: < 30 seconds detection and promotion
- **Data Consistency**: Streaming replication with timeline management
- **Self-Healing**: Event-driven recovery and service management

### 🎯 Quick Health Check

```bash
# Verify system reliability
sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf cluster show
systemctl status detect-rouge-primary.timer
sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;"
```

**Expected results:**
- One primary "* running", all replicas "running"
- Timer shows "active (waiting)"
- Replication shows connected replicas with minimal lag

### 📊 Reliability Metrics

- **Uptime Target**: 99.9%+ with proper maintenance
- **Failover Time**: < 30 seconds
- **Recovery Time**: < 2 minutes for node rejoin
- **Data Protection**: 100% split-brain detection and prevention

## Node Recovery Operations

### 🔄 Standard Node Rejoin

```bash
# Standard rejoin (when data is compatible)
sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf node rejoin \
    -d repmgr -h <primary-ip> -U repmgr --verbose

# Force rejoin with rewind (when timelines diverged)
sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf node rejoin \
    -d repmgr -h <primary-ip> -U repmgr --force-rewind --verbose
```

### 🚨 Emergency Recovery

#### **Complete Cluster Failure**
```bash
# 1. Find node with most recent data
for node in postgresql1 postgresql2 postgresql3; do
    ssh $node "sudo -u postgres pg_controldata /var/lib/postgresql/17/main | grep 'Latest checkpoint'"
done

# 2. Start best candidate as new primary
sudo systemctl unmask postgresql@17-main.service
sudo systemctl start postgresql@17-main.service
sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf primary register --force

# 3. Rejoin other nodes
sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf node rejoin \
    -d repmgr -h <new-primary-ip> -U repmgr --force-rewind --verbose
```

#### **Split-Brain Resolution**
```bash
# On the node that should become replica:
sudo systemctl unmask postgresql@17-main.service
sudo -u postgres repmgr -f /etc/repmgr/17-main/repmgr.conf node rejoin \
    -d repmgr -h <correct-primary-ip> -U repmgr --force-rewind --verbose
```

**Note:** If service is masked from split-brain protection, unmask it first with `sudo systemctl unmask postgresql@17-main.service`

## Wire Server Database Setup

The [`postgresql-wire-setup.yml`](../ansible/postgresql-playbooks/postgresql-wire-setup.yml) playbook creates the Wire server database and user account.

**Usage:** See the [Deployment Commands Reference](#deployment-commands-reference) section for all Wire setup commands.

**Important:** Generated password is displayed in Ansible output - save it securely for Wire server configuration.
