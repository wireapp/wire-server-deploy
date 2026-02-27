# Wire Server Upgrade Changes (5.5.0 -> 5.25.0)

This document captures the concrete changes applied during the upgrade work so the setup can be reproduced reliably.

## Environment Variable (Required)

**IMPORTANT:** Set `WIRE_BUNDLE_ROOT` to point to your new Wire bundle location. See [README.md](./README.md#environment-variable-required) for setup details.

```bash
export WIRE_BUNDLE_ROOT=/home/demo/wire-server-deploy-new
```

## Environment Context

- Admin host: hetzner3
- New bundle path: `${WIRE_BUNDLE_ROOT}` (e.g., `/home/demo/wire-server-deploy-new`)
- Existing deployment path: `/home/demo/wire-server-deploy` (current running version - do not change)
- Cluster access via `bin/offline-env.sh` and `d` wrapper

## Core Infrastructure Setup

### PostgreSQL and RabbitMQ (external)

- **PostgreSQL** deployed via `postgresql-external` chart
- **RabbitMQ** deployed via `rabbitmq-external` chart
- Credentials used for RabbitMQ: `guest/guest`
- PostgreSQL password pulled from secret:
  ```bash
  kubectl get secret wire-postgresql-external-secret -n default -o jsonpath='{.data.password}' | base64 -d
  ```

### MinIO / S3 (cargohold)

- MinIO is running on the minio nodes (validated with `mc admin info`)
- Cargohold configured to use `minio-external:9000`
- MinIO credentials taken from:
  `/home/demo/wire-server-deploy/ansible/inventory/offline/group_vars/all/secrets.yaml`

## Helm Charts / Values Changes

### 1. Wire-Utility

- Updated `charts/wire-utility/values.yaml` with PostgreSQL and RabbitMQ defaults
- Installed to enable cluster debugging and cqlsh access

### 2. postgres-exporter / Prometheus ScrapeConfig

- Updated `charts/postgresql-external/templates/scrape-config.yaml` to use:
  ```yaml
  release: kube-prometheus-stack
  ```
- Fixed Prometheus discovery issue

### 3. Wire Server Values (critical overrides)

**Mapped from** `wire-server-deploy/values/wire-server/values.yaml` into
`${WIRE_BUNDLE_ROOT}/values/wire-server/prod-values.example.yaml`:

- `brig.config.externalUrls.*`
- `brig.config.optSettings.setFederationDomain`
- `brig.config.optSettings.setSftStaticUrl`
- `brig.config.emailSMS.*`
- `brig.config.smtp.*`
- `nginz.nginx_conf.*`
- `spar.config.domain/appUri/ssoUri/contacts`
- `legalhold.host/wireApiHost`
- `cargohold.config.aws.*`

**Additional enforced settings:**

- `rabbitmq` host set to `rabbitmq-external`
- `postgresql` host set to `postgresql-external-rw`
- `cassandra` host set to `cassandra-external`
- `gundeck.config.redis.host` set to `redis-ephemeral-master`
- `galley.config.postgresMigration.conversation: cassandra`
- `background-worker.config.postgresMigration.conversation: cassandra`

### 4. Wire Server Secrets (critical overrides)

Mapped from `/home/demo/wire-server-deploy/values/wire-server/secrets.yaml`:

- `brig.secrets.zAuth.publicKeys`
- `brig.secrets.zAuth.privateKeys`
- `brig.secrets.turn.secret`
- `nginz.secrets.zAuth.publicKeys`
- `cargohold.secrets.awsKeyId`
- `cargohold.secrets.awsSecretKey`

**PostgreSQL password**:

- `brig.secrets.pgPassword`, `galley.secrets.pgPassword`, and `background-worker.secrets.pgPassword`
  set to the decoded secret from:
  ```bash
  kubectl get secret wire-postgresql-external-secret -n default -o jsonpath='{.data.password}' | base64 -d
  ```

## Migration Execution

### Cassandra schema migrations

```bash
cd ${WIRE_BUNDLE_ROOT}
source bin/offline-env.sh

d helm upgrade --install cassandra-migrations ./charts/wire-server/charts/cassandra-migrations \
  -n default \
  --set "cassandra.host=cassandra-external,cassandra.replicationFactor=3"
```

### Migrate-features

```bash
cd ${WIRE_BUNDLE_ROOT}
source bin/offline-env.sh

d helm upgrade --install migrate-features ./charts/migrate-features -n default
```

## Troubleshooting Fixes Applied

1. **nginz crashloop**
   - Fixed by mapping correct `external_env_domain` and `deeplink` endpoints
   - Fixed zAuth public key in secrets (nginz used wrong placeholder)

2. **brig crashloop (SMTP error)**
   - Fixed by setting `smtp.host: demo-smtp`

3. **galley crashloop (PG auth)**
   - Fixed by using correct `pgPassword` from secret

4. **gundeck redis errors**
   - Fixed by setting `redis.host: databases-ephemeral-redis-ephemeral`

5. **cargohold upload errors (403 / InvalidAccessKeyId)**
   - Fixed by setting correct MinIO credentials in secrets

6. **nginz crashloop (kube-dns resolver)**
   - Added `nginz.nginx_conf.dns_resolver: coredns` in `${WIRE_BUNDLE_ROOT}/values/wire-server/prod-values.example.yaml`
   - Redeployed wire-server to regenerate nginz configmap
   - Commands:
     ```bash
     cd ${WIRE_BUNDLE_ROOT}
     source bin/offline-env.sh
     d helm upgrade --install wire-server ./charts/wire-server \
       -f values/wire-server/prod-values.example.yaml \
       -f values/wire-server/prod-secrets.example.yaml \
       -n default
     ```

7. **elasticsearch-index-create mapping conflict (email_unvalidated)**
   - Deleted `directory` index and reran `elasticsearch-index-create` job via helm upgrade
   - Resolved 400 mapping conflict for `email_unvalidated`
   - Commands:
     ```bash
     cd ${WIRE_BUNDLE_ROOT}
     source bin/offline-env.sh

     # delete index
     d kubectl exec -n default wire-utility-0 -- /bin/sh -c \
       'curl -s -XDELETE http://elasticsearch-external:9200/directory'

     # rerun index-create job via helm
     d kubectl delete job -n default elasticsearch-index-create
     d helm upgrade --install wire-server ./charts/wire-server \
       -f values/wire-server/prod-values.example.yaml \
       -f values/wire-server/prod-secrets.example.yaml \
       -n default
     ```
   - Follow-up (reindex/refill from Cassandra):
     ```bash
     # per release notes, refill ES documents from Cassandra
     # see https://docs.wire.com/latest/developer/reference/elastic-search.html?h=index#refill-es-documents-from-cassandra
     # example (adjust if using custom settings):
     d kubectl exec -n default wire-utility-0 -- /bin/sh -c \
       'brig-index update --refresh --refill-from-cassandra'
     ```

8. **gundeck Redis connection timeout (redis-ephemeral network policy)**
   - Root cause: `databases-ephemeral` chart created a Redis NetworkPolicy with no ingress rules, blocking gundeck
   - Fix: disable the Redis NetworkPolicy in the `databases-ephemeral` release
   - Commands:
     ```bash
     cd ${WIRE_BUNDLE_ROOT}
     source bin/offline-env.sh

     d helm upgrade --install databases-ephemeral ./charts/databases-ephemeral \
       -n default --reuse-values \
       --set-json redis-ephemeral.redis-ephemeral.networkPolicy=null
    ```
   - Validation: gundeck logs show `successfully connected to Redis`

9. **Ingress timeout after upgrade (ingress-nginx controller rescheduled)**
   - Root cause: public traffic is forwarded to a specific kubenode, but ingress-nginx was rescheduled to a different node; with `externalTrafficPolicy: Local` this causes timeouts
   - Fix: pin ingress-nginx controller to the node receiving public traffic (per offline docs)
   - Commands:
     ```bash
     cd ${WIRE_BUNDLE_ROOT}
     source bin/offline-env.sh

     cat <<'EOF' > values/ingress-nginx-controller/node-selector.yaml
     ingress-nginx:
       controller:
         nodeSelector:
           kubernetes.io/hostname: kubenode1
     EOF

     d helm upgrade --install ingress-nginx-controller ./charts/ingress-nginx-controller \
       -n default --reuse-values -f values/ingress-nginx-controller/node-selector.yaml
     ```
   - Validation: `https://teams.b1.wire-demo.site/register/success/` returns HTTP 200

10. **Webapp login fails with MLS disabled (newer webapp build)**
   - Root cause: newer webapp build includes a core library change that requires `MLSService` at init time; when MLS is disabled server-side, the webapp throws `MLSService is required to construct ConversationService with MLS capabilities` and aborts login after calling `/v13/mls/public-keys` (400 `mls-not-enabled`).
   - Change introduced by core lib update in webapp `2025-12-10-production.0` (chart `webapp-0.8.0-pre.1963`, appVersion `v0.34.6-7b724e2`). The hard requirement was added in commit `d399c3d170` (2025-11-11).
   - Safe webapp version with MLS disabled: `2025-11-05-production.0` (image `quay.io/wire/webapp:2025-11-05-production.0`), which predates the MLS hard requirement. `2024-08-22-production.0` also works.
   - Workaround: keep MLS disabled and pin webapp to `2025-11-05-production.0` (or earlier), or re-enable MLS on the backend if you must run the newer webapp.

11. **Containerd image cleanup after migration**
   - Cleanup script (dry-run and apply) stored in `${WIRE_BUNDLE_ROOT}/bin/tools/cleanup-containerd-images.py`
   - Multi-node runner script stored in `${WIRE_BUNDLE_ROOT}/bin/tools/cleanup-containerd-images-all.sh`
   - Run across kubenodes via jump host using demo user; audit logs written per-node to `/home/demo/cleanup-logs`
   - Example command (runs on all nodes):
     ```bash
     ${WIRE_BUNDLE_ROOT}/bin/tools/cleanup-containerd-images-all.sh
     ```
   - Example audit logs:
     - `/home/demo/cleanup-logs/cleanup_192.168.122.21_<timestamp>.json`
     - `/home/demo/cleanup-logs/cleanup_192.168.122.22_<timestamp>.json`
     - `/home/demo/cleanup-logs/cleanup_192.168.122.23_<timestamp>.json`

## Verification Steps

- **Pod health**
  ```bash
  d kubectl get pods -n default | grep -E 'brig|galley|gundeck|cargohold|nginz'
  ```

- **MinIO connectivity from wire-utility**
  ```bash
  d kubectl exec wire-utility-0 -n default -- \
    mc alias set wire-minio http://minio-external:9000 \
    Ypjyx65pemPKhoo2SvMr nbZtd9R5aobrhlqAzaV7xUJiPuiCxAXyGb7TxvRJWE

  d kubectl exec wire-utility-0 -n default -- mc admin info wire-minio
  ```

- **Cassandra schema versions**
  - brig: 91
  - galley: 101
  - gundeck: 12
  - spar: 21

---

This file should be updated if any additional manual overrides are applied.
