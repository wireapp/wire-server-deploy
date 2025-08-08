# PostgreSQL Cluster Deployment 

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Inventory Definition](#inventory-definition)
- [Running the Playbook](#running-the-playbook)
- [PostgreSQL Packages Installation Playbook](#postgresql-packages-installation-playbook)
- [Deployment Architecture](#deployment-architecture)
- [Monitoring and Verification](#monitoring-and-verification)
- [Wire Server Database Setup](#wire-server-database-setup)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [Security Considerations](#security-considerations)

## OverviewostgreSQL Cluster Deployment

## Overview
The [`postgresql-deploy.yml`](../ansible/postgresql-deploy.yml) playbook is designed to deploy a highly available PostgreSQL cluster using streaming replication. The cluster consists of one primary (read-write) node and two replica (read-only) nodes, providing fault tolerance and read scaling capabilities. The deployment includes tasks for installing PostgreSQL packages, deploying the primary node, deploying replica nodes, verifying the deployment, and setting up the Wire server database and user.

## Architecture

### Cluster Topology
The PostgreSQL cluster implements a **Primary-Replica** architecture with **asynchronous streaming replication**:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   PostgreSQL1   │    │   PostgreSQL2   │    │   PostgreSQL3   │
│   (Primary)     │    │   (Replica)     │    │   (Replica)     │
│   Read/Write    │────│   Read-Only     │    │   Read-Only     │
│                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                       Streaming Replication
```

### Key Components

1. **Primary Node (postgresql1)**:
   - Handles all write operations and read queries
   - Sends WAL (Write-Ahead Log) records to replicas
   - Manages replication slots for each replica
   - Configured with `wal_level = replica`

2. **Replica Nodes (postgresql2, postgresql3)**:
   - Receive and apply WAL records from primary
   - Can handle read-only queries (hot standby)
   - Use physical replication slots for connection management
   - Automatically reconnect to primary if connection is lost

3. **Replication Mechanism**:
   - **Streaming Replication**: Real-time transmission of WAL records
   - **Asynchronous Mode**: Optimized for performance over strict consistency
   - **Physical Replication Slots**: Ensure WAL retention for disconnected replicas
   - **Hot Standby**: Replicas accept read-only queries during replication

### High Availability Features

- **Automatic Failover**: Manual promotion of replica to primary when needed
- **WAL Retention**: Primary retains WAL data for replica recovery
- **Connection Management**: Replicas automatically reconnect after network issues
- **Read Load Distribution**: Read queries can be distributed across replicas

## Inventory Definition
The PostgreSQL [inventory](../ansible/inventory/offline/99-static) is structured as follows:

```ini
[all]
postgresql1 ansible_host=192.168.122.236
postgresql2 ansible_host=192.168.122.233
postgresql3 ansible_host=192.168.122.206

[postgresql:vars]
postgresql_network_interface = enp1s0
wire_dbname = wire-server
wire_user = wire-server
# if not defined, a random password will be generated
# wire_pass = verysecurepassword

# Add all postgresql nodes here
[postgresql]
postgresql1
postgresql2
postgresql3
# Add all postgresql primary nodes here
[postgresql_rw]
postgresql1
# Add all postgresql read-only nodes here i.e. replicas
[postgresql_ro]
postgresql2
postgresql3

```

#### Node Groups:

- `postgresql`: Group containing all PostgreSQL nodes.
- `postgresql_rw`: Group containing the primary (read-write) PostgreSQL node.
- `postgresql_ro`: Group containing the replica (read-only) PostgreSQL nodes.

#### Variables:

- `postgresql_network_interface`: Network interface for PostgreSQL nodes (optional, defaults to `enp1s0`).
- `wire_dbname`: Name of the Wire server database.
- `wire_user`: User for the Wire server database.
- `wire_pass`: Password for the wire server, if not defined, a random password will be generated. Password will be displayed on the output once the playbook has finished creating the user. Use this password to configure wire-server helm charts.

### Running the Playbook

To run the [`postgresql-deploy.yml`](../ansible/postgresql-deploy.yml) playbook, use the following command:
```
ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/postgresql-deploy.yml # -e "skip_postgresql_wire_setup=true"
```

**Note**: The ansible commands should be run using the WSD_CONTAINER container as explained in the [Making tooling available in your environment](./docs_ubuntu_22.04.md#making-tooling-available-in-your-environment) documentation.

#### Skip Tags and Use Cases

The playbook includes several tasks that can be skipped by setting specific variables to `true`. These variables default to `false` if not specified, meaning the tasks will be executed unless explicitly skipped.

- `skip_postgresql_install`: Skip [PostgreSQL package installation](#postgresql-packages-installation-playbook). Useful if PostgreSQL is already installed.
- `skip_postgresql_primary`: Skip [primary PostgreSQL node deployment](#primary-node-deployment-process). Useful if the primary node is already set up.
- `skip_postgresql_replica`: Skip [replica PostgreSQL node deployment](#replica-node-deployment-process). Useful if replicas are already set up.
- `skip_postgresql_verify`: Skip [verification of the PostgreSQL deployment](#automated-verification-process). Useful if verification is not needed or has already been done.
- `skip_postgresql_wire_setup`: Skip [setup of the Wire server PostgreSQL database and user](#wire-server-database-setup). Useful if the database and user are already set up.

**Example with skip options**:
```bash
ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/postgresql-deploy.yml -e "skip_postgresql_wire_setup=true"
```


## PostgreSQL Packages Installation Playbook

### Overview
This playbook installs PostgreSQL packages and their dependencies on hosts belonging to the `postgresql` group. The installation supports both online repository-based installation and offline package deployment for air-gapped environments.

### Installation Architecture

The package installation follows a layered approach:

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Package Dependencies                         │
├─────────────────────────────────────────────────────────────────────┤
│  System Dependencies: libssl-dev, libllvm15, sysstat, ssl-cert     │
├─────────────────────────────────────────────────────────────────────┤
│  PostgreSQL Core: libpq5, postgresql-common, postgresql-client     │
├─────────────────────────────────────────────────────────────────────┤
│  PostgreSQL Server: postgresql-17, postgresql-client-17            │
├─────────────────────────────────────────────────────────────────────┤
│  Python Integration: python3-psycopg2                              │
└─────────────────────────────────────────────────────────────────────┘
```

### Variables

| Variable                     | Description                                                                 |
|------------------------------|-----------------------------------------------------------------------------|
| `postgresql_version`         | Version of PostgreSQL to install (e.g., 17).                                |
| `postgresql_data_dir`        | Directory where PostgreSQL data will be stored.                             |
| `postgresql_conf_dir`        | Directory where PostgreSQL configuration files will be stored.              |
| `repmgr_user`                | User for repmgr (PostgreSQL replication manager).                           |
| `repmgr_password`            | Password for the repmgr user.                                               |
| `repmgr_database`            | Database name for repmgr.                                                   |
| `postgresql_use_repository`  | Boolean to install packages from the repository (`true`) or from URLs (`false`). Default is `false`. |
| `postgresql_pkgs`            | List of dictionaries containing details about PostgreSQL packages to download and install. Each dictionary includes `name`, `url`, and `checksum`. |

### PostgreSQL Packages

The following packages are required for a complete PostgreSQL installation when not using an online repository:

1. **libpq5**: PostgreSQL C client library.
2. **postgresql-client-common**: Common files for PostgreSQL client applications.
3. **postgresql-common-dev**: Development files for PostgreSQL common components.
4. **postgresql-common**: Common scripts and files for PostgreSQL server and client packages.
5. **postgresql-client-17**: Client applications for PostgreSQL version 17.
6. **postgresql-17**: Main PostgreSQL server package for version 17.
7. **python3-psycopg2**: PostgreSQL adapter for Python.

### Offline Package Management

When not using the online repository (`postgresql_use_repository = false`), packages will be downloaded from the `assethost` setup. Ensure the offline sources are configured by running:

```bash
ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/setup-offline-sources.yml --limit assethost,postgresql
```

**Note**: If the above command has already been executed with the latest wire-server-deploy artifacts, avoid running it again. However, if PostgreSQL is being updated or installed for the first time, it is recommended to run this command to ensure all required packages are available from the latest wire-server-deploy artifacts. 

### Tasks

The installation process follows a systematic approach ensuring all dependencies are met:

1. **Install PostgreSQL dependencies**:
   - **System Libraries**: Installs core dependencies for PostgreSQL operation
     - `libssl-dev`: SSL/TLS support for secure connections
     - `libllvm15`: Required for JIT compilation support
     - `sysstat`: System performance monitoring tools
     - `ssl-cert`: SSL certificate management utilities
     - `libjson-perl`, `libipc-run-perl`: Perl libraries for PostgreSQL utilities

2. **Repository-based Installation** (when `postgresql_use_repository = true`):
   - **Package Selection**: Installs packages from PostgreSQL official repository
     - `postgresql-{{ postgresql_version }}`: Main server package
     - `postgresql-client-{{ postgresql_version }}`: Client tools and libraries
     - `python3-psycopg2`: Python database adapter for Ansible modules

3. **Offline Package Management** (when `postgresql_use_repository = false`):
   - **Version Verification**: Checks if packages are already installed to avoid conflicts
   - **Package Download**: Downloads `.deb` files from specified URLs with checksum verification
   - **Local Installation**: Installs packages using `dpkg` for air-gapped environments
   - **Cleanup Process**: Removes downloaded files to conserve disk space

4. **Package Integrity**:
   - **Checksum Validation**: Ensures package integrity during download
   - **Dependency Resolution**: Handles package dependencies automatically
   - **Installation Verification**: Confirms successful installation of all components

### Usage
To run the [`postgresql-install.yml`](../ansible/postgresql-playbooks/postgresql-install.yml) playbook independently, use the following command:

```bash
ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/postgresql-playbooks/postgresql-install.yml
```

## Deployment Architecture

### Primary Node Deployment Process

The primary node deployment is handled by the [`postgresql-deploy-primary.yml`](../ansible/postgresql-playbooks/postgresql-deploy-primary.yml) playbook, which performs the following key operations:

#### 1. Pre-deployment Checks
- **Replication User Verification**: Checks if the replication user (`repmgr_user`) already exists
- **Replication Slots Check**: Verifies existing replication slots for replica nodes
- **Service Status**: Ensures PostgreSQL service is ready for configuration

#### 2. Configuration Management
- **pg_hba.conf Configuration**: Sets up authentication rules for:
  - Local connections using peer authentication
  - Replication connections from replica nodes
  - Inter-cluster communication
- **Primary PostgreSQL Configuration**: Applies optimized settings via [postgresql_primary.conf.j2](../ansible/templates/postgresql_primary.conf.j2).

#### 3. Replication Setup
- **Replication User Creation**: Creates the replication user with `REPLICATION,LOGIN` privileges
- **Physical Replication Slots**: Creates dedicated slots for each replica (`postgresql2`, `postgresql3`)
- **Service Management**: Restarts and enables PostgreSQL service

#### 4. Readiness Verification
- **Port Availability**: Waits for PostgreSQL to accept connections on port 5432

### Replica Node Deployment Process

The replica deployment is managed by the [`postgresql-deploy-replica.yml`](../ansible/postgresql-playbooks/postgresql-deploy-replica.yml) playbook with the following workflow:

#### 1. Replica State Assessment
- **Configuration Check**: Verifies if replica is already configured (`standby.signal` file presence)
- **Service Status**: Checks current PostgreSQL service state
- **Data Directory**: Assesses existing data directory state

#### 2. Configuration Deployment
- **Authentication Setup**: Configures `pg_hba.conf` for replica-specific rules
- **Replica Configuration**: Applies [`postgresql_replica.conf.j2`](../ansible/templates/postgresql_replica.conf.j2) with:
  ```
  primary_conninfo = 'host=<primary_ip> user=<repmgr_user> ...'
  primary_slot_name = '<replica_hostname>'
  hot_standby = on
  max_standby_streaming_delay = 120s
  ```

#### 3. Base Backup Process
For unconfigured replicas, the playbook performs:
- **Service Shutdown**: Stops PostgreSQL service safely
- **Data Directory Cleanup**: Removes existing data to prevent conflicts
- **pg_basebackup Execution**: Creates replica from primary using:
  ```bash
  pg_basebackup -h <primary> -U <repmgr_user> -D <data_dir> -P -R -X stream
  ```
- **Standby Signal**: Creates `standby.signal` file to mark as replica

#### 4. Replica Activation
- **Service Startup**: Starts PostgreSQL in hot standby mode
- **Connection Verification**: Ensures replica connects to primary successfully
- **Replication PostgreSQL service Status**: Waits for PostgreSQL to accept connections on port 5432

### Security Configuration

#### Authentication Matrix
The [`pg_hba.conf`](../ansible/templates/pg_hba.conf.j2) template implements a security model with:

| Connection Type | User | Source | Method | Purpose |
|----------------|------|--------|---------|---------|
| Local | All | Unix Socket | peer | Local admin access |
| Host | All | 127.0.0.1/32 | md5 | Local TCP connections |
| Host | repmgr_user | replica_nodes | md5 | Streaming replication |
| Host | All | primary_network | md5 | Inter-cluster communication |

#### Network Security
- **Restricted Access**: Only defined IP addresses can connect
- **Encrypted Connections**: MD5 authentication for network connections
- **Replication Isolation**: Dedicated user for replication traffic

### Performance Optimization

#### Resource-Constrained Configuration
The deployment is optimized for environments with limited resources (1GB RAM, 1 core, 50GB disk):

**Memory Settings:**
- `shared_buffers = 128MB` (~12.5% of RAM)
- `effective_cache_size = 512MB` (~50% of RAM)
- `work_mem = 2MB` (conservative for limited memory)
- `maintenance_work_mem = 32MB`

**WAL Management:**
- `wal_keep_size = 2GB` (4% of disk space)
- `max_slot_wal_keep_size = 3GB` (6% of disk space)
- `wal_writer_delay = 200ms` (optimized for single core)

**Replication Tuning:**
- Asynchronous replication for performance
- Physical replication slots for reliability
- Optimized timeouts for resource constraints

## Monitoring and Verification

### Automated Verification Process

The [`postgresql-verify-HA.yml`](../ansible/postgresql-playbooks/postgresql-verify-HA.yml) playbook provides comprehensive health checks:

#### 1. Streaming Replication Status
Monitors real-time replication metrics:
```sql
SELECT 
  client_addr, 
  application_name, 
  state, 
  sync_state,
  pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)) as lag_size,
  CASE 
    WHEN pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) = 0 THEN 'SYNCHRONIZED'
    WHEN pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) < 1024*1024 THEN 'NEAR_SYNC'
    ELSE 'LAGGING'
  END as status
FROM pg_stat_replication;
```

#### 2. Replication Slot Health
Validates slot availability and lag:
```sql
SELECT 
  slot_name, 
  active, 
  pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) as slot_lag,
  CASE 
    WHEN active THEN 'ACTIVE'
    ELSE 'INACTIVE - CHECK REPLICA'
  END as slot_status
FROM pg_replication_slots;
```

### Manual Health Checks

#### Primary Node Status
```bash
# Check replication status
sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;"

# Verify replication slots
sudo -u postgres psql -c "SELECT * FROM pg_replication_slots;"

# Check WAL sender processes
ps aux | grep "walsender"
```

#### Replica Node Status from replica nodes
```bash
# Check replica status
sudo -u postgres psql -c "SELECT * FROM pg_stat_wal_receiver;"

# Verify hot standby mode
sudo -u postgres psql -c "SELECT pg_is_in_recovery();"

# Check replication lag
sudo -u postgres psql -c "SELECT EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp()));"
```

### Performance Metrics # TODO

#### Key Performance Indicators
1. **Replication Lag**: Should be < 1MB under normal load
2. **Connection Count**: Monitor active connections vs. max_connections
3. **WAL Generation Rate**: Track WAL file creation frequency
4. **Disk Usage**: Monitor WAL directory and data directory sizes

#### Health Thresholds
- **Replication Lag**: Alert if > 5MB
- **Connection Usage**: Alert if > 80% of max_connections
- **Disk Usage**: Alert if WAL directory > 10% of total disk
- **Recovery Time**: Replica restart should complete within 2 minutes

## Wire Server Database Setup

### PostgreSQL Wire Setup Playbook

The [`postgresql-wire-setup.yml`](../ansible/postgresql-playbooks/postgresql-wire-setup.yml) playbook is the final step in the PostgreSQL cluster deployment process. This playbook creates the dedicated database and user account required for Wire server operation.

#### Overview
This playbook runs exclusively on the primary PostgreSQL node (`postgresql_rw` group) and performs the following operations:

1. **Database Management**:
   - Checks if the Wire server database `wire_dbname` already exists
   - Creates the database if it doesn't exist

2. **User Account Management**:
   - Verifies if the Wire server user account exists
   - Creates a new user account if needed
   - Generates a secure random password if `wire_pass` is not defined

3. **Credential Management**:
   - Displays generated credentials for the `wire_user`
   - Ensures secure password generation (15 characters, alphanumeric)

#### Usage
This playbook is automatically executed as part of the main `postgresql-deploy.yml` workflow, but can be run independently:

```bash
ansible-playbook -i ansible/inventory/offline/hosts.ini ansible/postgresql-playbooks/postgresql-wire-setup.yml
```

#### Important Notes
- **Credential Security**: The generated password is displayed in the Ansible output. Ensure this output is securely stored and the password is updated in your Wire server configuration.

## Troubleshooting

### Common Issues and Solutions

#### 1. Replication Connection Issues
**Symptoms**: Replica cannot connect to primary
**Diagnosis**:
```bash
# Check network connectivity
telnet <primary_ip> 5432

# Verify authentication
sudo -u postgres psql -h <primary_ip> -U <repmgr_user> -d postgres
```
**Solutions**:
- Verify `pg_hba.conf` entries for replication user
- Check firewall rules on primary node
- Validate replication user credentials

#### 2. Replication Lag Issues
**Symptoms**: High replication lag or replicas falling behind
**Diagnosis**:
```sql
-- Check WAL generation rate on primary
SELECT * FROM pg_stat_wal;

-- Monitor replication lag
SELECT * FROM pg_stat_replication;
```
**Solutions**:
- Increase `wal_keep_size` on primary
- Check network bandwidth between nodes
- Optimize replica hardware resources

#### 3. Wire Database Connection Issues
**Symptoms**: Wire server cannot connect to PostgreSQL database
**Diagnosis**:
```bash
# Test database connectivity
sudo -u postgres psql -d <wire_dbname> -U <wire_user> -h <primary_ip>

# Check user privileges
sudo -u postgres psql -c "\du <wire_user>"
```
**Solutions**:
- Verify database and user exist on primary node
- Check `pg_hba.conf` allows connections from Wire server hosts
- Validate credentials in Wire server configuration
