# Wire Sync Tools

This folder contains helper scripts to audit and sync offline assets for the Wire Server upgrade.

## Environment Variable (Required)

**IMPORTANT:** All commands in this guide require the `WIRE_BUNDLE_ROOT` environment variable to point to your new Wire bundle location.

### Setup Steps:

1. **Unpack the new bundle** into a dedicated folder (e.g., `wire-server-deploy-new`)
2. **Set the environment variable** to point to that folder path
3. **Use the variable** in all commands

### Examples:

```bash
# Unpack your new bundle
mkdir -p /home/demo/wire-server-deploy-new
tar -xzf assets.tgz -C /home/demo/wire-server-deploy-new

# Set the bundle root to the unpacked location
export WIRE_BUNDLE_ROOT=/home/demo/wire-server-deploy-new
```

**Note:** All examples use `/home/demo/wire-server-deploy-new` as a placeholder. Replace it with your actual bundle location by setting `WIRE_BUNDLE_ROOT`.

## Prerequisites

Before using these tools, ensure the following:

1. **Copy kubeconfig from existing deployment to new bundle:**
   ```bash
   # Copy kubeconfig.dec from existing deployment to new bundle
   # Note: /home/demo/wire-server-deploy is your EXISTING deployment path
   cp /home/demo/wire-server-deploy/ansible/inventory/kubeconfig.dec \
      ${WIRE_BUNDLE_ROOT}/ansible/inventory/kubeconfig.dec
   ```

2. **SSH access configured:**
   - SSH key-based authentication to all nodes (kubenodes, cassandra nodes, assethost)
   - `demo` user with passwordless sudo (for containerd cleanup)

3. **Ansible installed** on the admin host (for wire_sync_binaries.py and wire_sync_images.py)

## Usage Location

Copy these tools into your new bundle and run them from the admin host:

```bash
# Set your bundle location first (replace with your actual path)
export WIRE_BUNDLE_ROOT=/home/demo/wire-server-deploy-new

# Copy tools to the bundle
cp -R offline/upgrades/tools/* ${WIRE_BUNDLE_ROOT}/bin/tools/
chmod +x ${WIRE_BUNDLE_ROOT}/bin/tools/*.sh
```

### Option 2: Copy from Repository

If the tools are not in your bundle, copy them from the wire-server-deploy repository:

```bash
# On your local machine or build server, from the wire-server-deploy repo root
# Include the tools in your bundle before building/packaging
cp -R offline/upgrades/tools/* <path-to-bundle-staging>/bin/tools/

# OR manually copy to admin host after bundle extraction:

# 1. On admin host: Set your bundle location
export WIRE_BUNDLE_ROOT=/home/demo/wire-server-deploy-new

# 2. Create tools directory
mkdir -p ${WIRE_BUNDLE_ROOT}/bin/tools

# 3. From your local machine with the repo: Copy tools to admin host
scp -r offline/upgrades/tools/* adminhost:${WIRE_BUNDLE_ROOT}/bin/tools/

# 4. On admin host: Make scripts executable
chmod +x ${WIRE_BUNDLE_ROOT}/bin/tools/*.sh
```

**Note:** These tools are located in the `offline/upgrades/tools/` directory of the wire-server-deploy repository.

## Scripts

- `wire_sync_binaries.py`
  - Generates `hosts.ini` from `99-static` + current inventory (optional).
  - Dry-run checks tar files, SSH to assethost, and Kubernetes access.
  - Runs Ansible `setup-offline-sources.yml` to sync binaries/debs/containers to assethost.
  - Writes JSON + text audit logs to `/var/log/audit_log`.

- `wire_sync_images.py`
  - Dry-run checks SSH to assethost, Kubernetes access, and container index files on assethost.
  - Runs Ansible `seed-offline-containerd.yml` to import images into containerd on all nodes.
  - Writes JSON + text audit logs to `/var/log/audit_log`.

- `wire_sync_lib.py`
  - Shared utility library (hashing, audit logs, hosts generation, command execution).

- `cassandra_backup.py`
  - Creates Cassandra snapshots for backup purposes.
  - Supports restore from snapshot.
  - Can list keyspaces and snapshots.

- `cleanup-containerd-images.py`
  - Cleans up unused containerd images on a single node.
  - Supports dry-run and apply with audit logs.

- `cleanup-containerd-images-all.sh`
  - Runs image cleanup sequentially across kubenode1-3.
  - Uses SSH to run `cleanup-containerd-images.py` on each node.

- `upgrade-all-charts.sh`
  - Upgrades all charts in the `${WIRE_BUNDLE_ROOT}/charts` directory in a fixed order.
  - Adds required `--set` values for nginx-ingress-services and reaper.

## Documentation

- [CASSANDRA_MIGRATIONS.md](./CASSANDRA_MIGRATIONS.md) - How to run Cassandra schema migrations

## Cassandra Backup Tool

### Create Backup

```bash
# SSH to admin host with SSH access to Cassandra nodes
ssh adminhost

# Set bundle root
export WIRE_BUNDLE_ROOT=/home/demo/wire-server-deploy-new

# Run backup for all keyspaces
python3 ${WIRE_BUNDLE_ROOT}/bin/tools/cassandra_backup.py \
  --keyspaces brig,galley,gundeck,spar \
  --snapshot-name pre-migration-5.25 \
  --hosts <cassandra-hosts> \
  --verbose

# Or backup specific keyspaces
python3 ${WIRE_BUNDLE_ROOT}/bin/tools/cassandra_backup.py \
  --keyspaces brig,galley \
  --snapshot-name pre-migration-5.25

# Dry-run to see what would happen
python3 ${WIRE_BUNDLE_ROOT}/bin/tools/cassandra_backup.py --dry-run
```

### List Snapshots

```bash
python3 ${WIRE_BUNDLE_ROOT}/bin/tools/cassandra_backup.py \
  --list-snapshots \
  --snapshot-name pre-migration-5.25
```

### List Keyspaces

```bash
python3 ${WIRE_BUNDLE_ROOT}/bin/tools/cassandra_backup.py --list-keyspaces
```

### Restore from Snapshot

```bash
# WARNING: This will overwrite existing data!
python3 ${WIRE_BUNDLE_ROOT}/bin/tools/cassandra_backup.py \
  --restore \
  --snapshot-name pre-migration-5.25 \
  --keyspaces brig
```

### Options

| Option | Description |
|--------|-------------|
| `--keyspaces` | Comma-separated keyspaces or "all" (default: brig,galley,gundeck,spar) |
| `--snapshot-name` | Name for the snapshot |
| `--hosts` | Override Cassandra hosts (comma-separated) |
| `--backup-dir` | Where to store backups (default: /tmp/cassandra-backups) |
| `--clear-snapshots` | Clear snapshots after backup |
| `--verbose` | Enable verbose output |
| `--dry-run` | Show what would happen |
| `--restore` | Restore from snapshot |
| `--list-snapshots` | List existing snapshots |
| `--list-keyspaces` | List available keyspaces |

## Quick Start (dry-run only)

```bash
# SSH to admin host
ssh adminhost

# Set bundle root
export WIRE_BUNDLE_ROOT=/home/demo/wire-server-deploy-new

# Create audit log directory
sudo mkdir -p /var/log/audit_log
sudo chown demo:demo /var/log/audit_log

# Navigate to bundle root
cd ${WIRE_BUNDLE_ROOT}

# Run dry-run tests
./bin/tools/wire_sync_binaries.py --generate-hosts --dry-run --use-d
./bin/tools/wire_sync_images.py --dry-run --use-d
```

## Run (when ready)

```bash
# Set bundle root
export WIRE_BUNDLE_ROOT=/home/demo/wire-server-deploy-new

# Navigate to bundle root
cd ${WIRE_BUNDLE_ROOT}

# Execute actual sync
./bin/tools/wire_sync_binaries.py --generate-hosts --use-d
./bin/tools/wire_sync_images.py --use-d
```

## Wire Sync Scripts Options

Both `wire_sync_binaries.py` and `wire_sync_images.py` support the following options:

| Option | Description |
|--------|-------------|
| `--generate-hosts` | Generate hosts.ini from inventory (only needed first time) |
| `--dry-run` | Validate without executing Ansible |
| `--use-d` | Use the `d` wrapper for Kubernetes access |
| `--verbose` | Show Ansible playbook output in real-time |

Example with verbose:

```bash
./bin/tools/wire_sync_binaries.py --use-d --verbose
./bin/tools/wire_sync_images.py --use-d --verbose
```

## Containerd Image Cleanup

### Dry-run (single node)

```bash
# Set bundle root
export WIRE_BUNDLE_ROOT=/home/demo/wire-server-deploy-new

${WIRE_BUNDLE_ROOT}/bin/tools/cleanup-containerd-images.py --sudo \
  --kubectl-shell \
  --kubectl-cmd "cd ${WIRE_BUNDLE_ROOT} && source bin/offline-env.sh && d kubectl --kubeconfig ${WIRE_BUNDLE_ROOT}/ansible/inventory/kubeconfig.dec"
```

### Apply (single node)

```bash
${WIRE_BUNDLE_ROOT}/bin/tools/cleanup-containerd-images.py --sudo --apply \
  --kubectl-shell \
  --kubectl-cmd "cd ${WIRE_BUNDLE_ROOT} && source bin/offline-env.sh && d kubectl --kubeconfig ${WIRE_BUNDLE_ROOT}/ansible/inventory/kubeconfig.dec"
```

### Options

| Option | Description |
|--------|-------------|
| `--apply` | Delete unused images (default is dry-run) |
| `--sudo` | Run `crictl`/`ctr` with sudo |
| `--kubectl-cmd` | Kubectl command wrapper (default: `d kubectl`) |
| `--kubectl-shell` | Run kubectl via a shell (needed for `source bin/offline-env.sh`) |
| `--crictl-cmd` | Override crictl command (default: `crictl`) |
| `--log-dir` | Write audit logs to this directory |
| `--audit-tag` | Tag included in audit log filename |

### Multi-node cleanup

```bash
# Set bundle root
export WIRE_BUNDLE_ROOT=/home/demo/wire-server-deploy-new

# Run cleanup on all nodes (automatically copies script to each node first)
${WIRE_BUNDLE_ROOT}/bin/tools/cleanup-containerd-images-all.sh
```

This script:
- Automatically copies `cleanup-containerd-images.py` to each kubenode
- Runs cleanup sequentially on all kubenodes
- Writes node logs to `/home/demo/cleanup-logs` (on each node)
- Writes a combined log to `${WIRE_BUNDLE_ROOT}/bin/tools/logs` (on admin host)

## Chart Upgrade Helper

```bash
# Set bundle root
export WIRE_BUNDLE_ROOT=/home/demo/wire-server-deploy-new

${WIRE_BUNDLE_ROOT}/bin/tools/upgrade-all-charts.sh
```

## Environment Overrides

You can override defaults with environment variables:

- `WIRE_SYNC_BUNDLE`
- `WIRE_SYNC_INVENTORY`
- `WIRE_SYNC_PLAYBOOK`
- `WIRE_SYNC_LOG_DIR`
- `WIRE_SYNC_KUBECONFIG`
- `WIRE_SYNC_ASSETHOST`
- `WIRE_SYNC_SSH_USER`
- `WIRE_SYNC_OFFLINE_ENV`
- `WIRE_SYNC_HOST_ROOT`
- `WIRE_SYNC_CONTAINER_ROOT`
- `WIRE_SYNC_TEMPLATE`
- `WIRE_SYNC_SOURCE_HOSTS`
- `WIRE_SYNC_OUTPUT_HOSTS`

Example:

```bash
# Set bundle root first
export WIRE_BUNDLE_ROOT=/home/demo/wire-server-deploy-new  # Replace with your actual bundle path

# Use it in environment overrides
WIRE_SYNC_LOG_DIR=/var/log/audit_log \
WIRE_SYNC_KUBECONFIG=${WIRE_BUNDLE_ROOT}/ansible/inventory/kubeconfig.dec \
./bin/tools/wire_sync_binaries.py --generate-hosts --dry-run --use-d
```

## Notes

- Duplicate entries inside tar files are **reported** and **skipped** in the audit report; they do not stop execution unless you pass `--fail-on-duplicates`.
- Dry-run prints errors but does not execute Ansible.
