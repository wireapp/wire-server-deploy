# Running Cassandra Migrations

This document explains how to run Cassandra schema migrations for the wire-server upgrade.

## Prerequisites

1. **SSH to hetzner3** (or any admin host with kubectl access)
2. **Images synced** - Ensure container images are synced to k8s cluster first:
   ```bash
   ssh hetzner3
   cd /home/demo/new
   ./bin/tools/wire_sync_images.py --use-d --verbose
   ```

## Running Cassandra Migrations

### Step 1: Sync Images (if not already done)

```bash
ssh hetzner3
cd /home/demo/new
./bin/tools/wire_sync_images.py --use-d --verbose
```

### Step 2: Run cassandra-migrations

```bash
cd /home/demo/new
source bin/offline-env.sh

# Install cassandra-migrations chart
d helm upgrade --install cassandra-migrations ./charts/wire-server/charts/cassandra-migrations \
  -n default \
  --set "cassandra.host=cassandra-external,cassandra.replicationFactor=3"
```

### Step 3: Verify Migrations

Check that the migration job completed:

```bash
d kubectl get pods -n default | grep cassandra-migrations
# Should show: cassandra-migrations-xxxxx   0/1   Completed
```

### Step 4: Verify Schema Versions

Connect to Cassandra via wire-utility pod and check versions:

```bash
# Check brig version (target: 91)
d kubectl exec -it wire-utility-0 -n default -- \
  cqlsh cassandra-external -u cassandra -p cassandra -e 'SELECT MAX(version) FROM brig.meta;'

# Check galley version (target: 101)
d kubectl exec -it wire-utility-0 -n default -- \
  cqlsh cassandra-external -u cassandra -p cassandra -e 'SELECT MAX(version) FROM galley.meta;'

# Check gundeck version (target: 12)
d kubectl exec -it wire-utility-0 -n default -- \
  cqlsh cassandra-external -u cassandra -p cassandra -e 'SELECT MAX(version) FROM gundeck.meta;'

# Check spar version (target: 21)
d kubectl exec -it wire-utility-0 -n default -- \
  cqlsh cassandra-external -u cassandra -p cassandra -e 'SELECT MAX(version) FROM spar.meta;'
```

## Expected Versions

| Service | Target Version |
|---------|---------------|
| brig | 91 |
| galley | 101 |
| gundeck | 12 |
| spar | 21 |

## Troubleshooting

### Check migration logs

```bash
# Get the pod name
POD=$(kubectl get pods -n default | grep cassandra-migrations | awk '{print $1}')

# Check logs for each service
kubectl logs $POD -c brig-schema -n default
kubectl logs $POD -c galley-schema -n default
kubectl logs $POD -c gundeck-schema -n default
kubectl logs $POD -c spar-schema -n default
```

### Re-run migrations

If migrations failed, you can delete and re-run:

```bash
d helm uninstall cassandra-migrations -n default

d helm upgrade --install cassandra-migrations ./charts/wire-server/charts/cassandra-migrations \
  -n default \
  --set "cassandra.host=cassandra-external,cassandra.replicationFactor=3"
```

## Command Summary

```bash
# Full command to run cassandra-migrations
cd /home-demo/new
source bin/offline-env.sh
d helm upgrade --install cassandra-migrations ./charts/wire-server/charts/cassandra-migrations \
  -n default \
  --set "cassandra.host=cassandra-external,cassandra.replicationFactor=3"
```
