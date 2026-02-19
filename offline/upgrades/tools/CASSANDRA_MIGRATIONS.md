# Running Cassandra Migrations

This document explains how to run Cassandra schema migrations for the wire-server upgrade.

## Environment Variable (Required)

**IMPORTANT:** All commands in this guide require the `WIRE_BUNDLE_ROOT` environment variable to point to your new Wire bundle location.

See [README.md](./README.md#environment-variable-required) for detailed setup instructions on unpacking the bundle and setting the environment variable.

**Quick reference:**

```bash
# Set the bundle root to your unpacked bundle location
export WIRE_BUNDLE_ROOT=/home/demo/wire-server-deploy-new
```

## Prerequisites

1. **SSH to admin host** (e.g., hetzner3) with kubectl access
2. **Set environment variable** - Export `WIRE_BUNDLE_ROOT` pointing to your bundle
3. **Images synced** - Container images must be synced to k8s cluster first (see Step 1 below)

## Running Cassandra Migrations

### Step 1: Sync Images (if not already done)

```bash
# SSH to admin host
ssh hetzner3

# Set bundle root
export WIRE_BUNDLE_ROOT=/home/demo/wire-server-deploy-new

# Sync container images to k8s cluster
cd ${WIRE_BUNDLE_ROOT}
./bin/tools/wire_sync_images.py --use-d --verbose
```

### Step 2: Run cassandra-migrations

```bash
# Set bundle root (if not already set in current session)
export WIRE_BUNDLE_ROOT=/home/demo/wire-server-deploy-new

cd ${WIRE_BUNDLE_ROOT}
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
# Set bundle root
export WIRE_BUNDLE_ROOT=/home/demo/wire-server-deploy-new

# Full command to run cassandra-migrations
cd ${WIRE_BUNDLE_ROOT}
source bin/offline-env.sh
d helm upgrade --install cassandra-migrations ./charts/wire-server/charts/cassandra-migrations \
  -n default \
  --set "cassandra.host=cassandra-external,cassandra.replicationFactor=3"
```
