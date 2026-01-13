# Cassandra Upgrade Guide: 3.11.16 → 3.11.19

## Prerequisites

1. Download latest offline assets from wire-builds:
   ```bash
   # Get the latest commit hash from wire-server-deploy repository
   # Download from S3 (example with hash):
   wget https://s3-eu-west-1.amazonaws.com/public.wire.com/artifacts/wire-server-deploy-static-<commit-hash>.tgz

   # Example:
   # wget https://s3-eu-west-1.amazonaws.com/public.wire.com/artifacts/wire-server-deploy-static-c45aa05622930280ba9e356312410055bb10ea0a.tgz

   tar -xzf wire-server-deploy-static-<commit-hash>.tgz
   ```

2. Extract Cassandra binary and ansible roles:
   ```bash
   # After extraction, you'll find:
   # - Cassandra binary: binaries/apache-cassandra-3.11.19-bin.tar.gz
   # - Ansible scripts: ansible/ directory with updated playbooks
   ```

3. Copy Cassandra binary to assethost:
   ```bash
   scp binaries/apache-cassandra-3.11.19-bin.tar.gz <assethost>:/opt/assets/binaries/
   ```

4. Copy necessary ansible files to admin host:
   ```bash
   # Copy updated Cassandra playbooks
   scp ansible/db-operations/cassandra_pre_upgrade.yml <admin-host>:~/wire-server-deploy/ansible/db-operations/
   scp ansible/db-operations/cassandra_post_upgrade.yml <admin-host>:~/wire-server-deploy/ansible/db-operations/
   scp ansible/db-operations/cassandra_restart.yml <admin-host>:~/wire-server-deploy/ansible/db-operations/
   scp ansible/cassandra.yml <admin-host>:~/wire-server-deploy/ansible/

   # Copy updated ansible-cassandra role
   rsync -av ansible/roles-external/ansible-cassandra/ <admin-host>:~/wire-server-deploy/ansible/roles-external/ansible-cassandra/
   ```

5. Update inventory to version 3.11.19 on admin host:
   ```bash
   # Option A: Copy the updated offline.yml from extracted assets
   scp ansible/inventory/offline/group_vars/all/offline.yml <admin-host>:~/wire-server-deploy/ansible/inventory/offline/group_vars/all/

   # Option B: Manually edit on admin host
   # Edit: ansible/inventory/offline/group_vars/all/offline.yml
   cassandra_version: "3.11.19"
   cassandra_url: "{{ binaries_url }}/apache-cassandra-3.11.19-bin.tar.gz"
   ```

## Upgrade Steps

### 1. Pre-upgrade (backups and repairs)
```bash
ansible-playbook -i ansible/inventory/offline/hosts.ini db-operations/cassandra_pre_upgrade.yml
```
- Removes cron jobs
- Upgrades sstables
- Runs full repairs


### 2. Install new binaries
```bash
ansible-playbook -i ansible/inventory/offline/hosts.ini cassandra.yml
```
- Downloads and installs new Cassandra version
- Updates symlinks
- Does NOT restart service

### 3. Restart services (manual rolling restart)
```bash
# On each node, one at a time:
ssh ansnode1 'sudo systemctl restart cassandra.service'
# Wait 30-60s for startup, monitor with:
ssh ansnode1 'sudo journalctl -u cassandra.service -f'

# Verify version and cluster health:
ssh ansnode1 'nodetool version && nodetool status'

# Repeat for remaining nodes (ansnode2, ansnode3, ...)
```

### 4. Post-upgrade (sstable optimization)
```bash
ansible-playbook -i inventory/<env>/hosts.ini db-operations/cassandra_post_upgrade.yml
```
- Upgrades sstables to new format
- Verifies cluster health

## Verification

### 1. Check cluster health
```bash
# On any Cassandra node:
nodetool status
# Expected: All nodes show UN (Up/Normal)
# UN  192.168.122.31  3.79 MiB   256          100.0%
# UN  192.168.122.32  3.77 MiB   256          100.0%
# UN  192.168.122.33  3.78 MiB   256          100.0%

nodetool describecluster
# Expected: Single schema version for all nodes
# Schema versions:
#   f9b63496-4819-3ad2-9b54-46c3439edade: [192.168.122.31, 192.168.122.32, 192.168.122.33]
```

### 2. Verify version on all nodes
```bash
ssh ansnode1 'nodetool version'  # Expected: ReleaseVersion: 3.11.19
ssh ansnode2 'nodetool version'  # Expected: ReleaseVersion: 3.11.19
ssh ansnode3 'nodetool version'  # Expected: ReleaseVersion: 3.11.19
```

### 3. Verify data integrity with cqlsh
```bash
# Connect to Cassandra
cqlsh <node-ip>

# Check keyspaces
DESCRIBE KEYSPACES;

# Check data in Wire keyspaces
SELECT COUNT(*) FROM brig.user;
SELECT COUNT(*) FROM galley.team;

# Verify you can read sample data
SELECT * FROM brig.user LIMIT 5;

# Exit cqlsh
exit
```

## Notes

- Minimum 3-node cluster required for zero-downtime upgrade
- Always restart nodes one at a time (serial: 1)
- Wait for each node to fully start before proceeding to next node
- Monitor startup: `sudo journalctl -u cassandra.service -f`
- `cassandra_restart.yml` playbook not compatible with offline/systemd environments
