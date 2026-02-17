# Wire Sync Tools

## Usage location

Copy these tools into the new bundle and run them from the admin host:

```
cp -R offline/upgrades/tools/* /home/demo/new/bin/tools/
chmod +x /home/demo/new/bin/tools/*.sh
```


This folder contains helper scripts to audit and sync offline assets for the Wire Server upgrade.

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
  - Upgrades all charts in the `/home/demo/new/charts` bundle in a fixed order.
  - Adds required `--set` values for nginx-ingress-services and reaper.

## Documentation

- [CASSANDRA_MIGRATIONS.md](./CASSANDRA_MIGRATIONS.md) - How to run Cassandra schema migrations

## Cassandra Backup Tool

### Create Backup

```bash
# SSH to hetzner3 (or any admin host with SSH access to Cassandra nodes)
ssh hetzner3

# Run backup for all keyspaces
python3 /Users/sukanta.ghosh/Workspace/tools/cassandra_backup.py \
  --keyspaces brig,galley,gundeck,spar \
  --snapshot-name pre-migration-5.25 \
  --hosts 192.168.122.31,192.168.122.32,192.168.122.33 \
  --verbose

# Or backup specific keyspaces
python3 /Users/sukanta.ghosh/Workspace/tools/cassandra_backup.py \
  --keyspaces brig,galley \
  --snapshot-name pre-migration-5.25

# Dry-run to see what would happen
python3 /Users/sukanta.ghosh/Workspace/tools/cassandra_backup.py --dry-run
```

### List Snapshots

```bash
python3 /Users/sukanta.ghosh/Workspace/tools/cassandra_backup.py \
  --list-snapshots \
  --snapshot-name pre-migration-5.25
```

### List Keyspaces

```bash
python3 /Users/sukanta.ghosh/Workspace/tools/cassandra_backup.py --list-keyspaces
```

### Restore from Snapshot

```bash
# WARNING: This will overwrite existing data!
python3 /Users/sukanta.ghosh/Workspace/tools/cassandra_backup.py \
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
ssh hetzner3
sudo mkdir -p /var/log/audit_log
sudo chown demo:demo /var/log/audit_log

cd /home/demo/new

./bin/tools/wire_sync_binaries.py --generate-hosts --dry-run --use-d
./bin/tools/wire_sync_images.py --dry-run --use-d
```

## Run (when ready)

```bash
cd /home/demo/new

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
/home/demo/new/bin/tools/cleanup-containerd-images.py --sudo \
  --kubectl-shell \
  --kubectl-cmd 'cd /home/demo/new && source bin/offline-env.sh && d kubectl --kubeconfig /wire-server-deploy/ansible/inventory/kubeconfig.dec'
```

### Apply (single node)

```bash
/home/demo/new/bin/tools/cleanup-containerd-images.py --sudo --apply \
  --kubectl-shell \
  --kubectl-cmd 'cd /home/demo/new && source bin/offline-env.sh && d kubectl --kubeconfig /wire-server-deploy/ansible/inventory/kubeconfig.dec'
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
/home/demo/new/bin/tools/cleanup-containerd-images-all.sh
```

This runs cleanup sequentially on kubenode1-3 and writes:
- node logs to `/home/demo/cleanup-logs`
- a combined log to `/home/demo/new/bin/tools/logs`

## Chart Upgrade Helper

```bash
/home/demo/new/bin/tools/upgrade-all-charts.sh
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
WIRE_SYNC_LOG_DIR=/var/log/audit_log \
WIRE_SYNC_KUBECONFIG=/home/demo/new/ansible/inventory/kubeconfig.dec \
./bin/tools/wire_sync_binaries.py --generate-hosts --dry-run --use-d
```

## Notes

- Duplicate entries inside tar files are **reported** and **skipped** in the audit report; they do not stop execution unless you pass `--fail-on-duplicates`.
- Dry-run prints errors but does not execute Ansible.
