#!/usr/bin/env bash
set -euo pipefail

cd /home/demo/new
source bin/offline-env.sh

log_dir=/home/demo/new/bin/tools/logs
mkdir -p "$log_dir"
log_file="$log_dir/upgrade-all-charts-$(date +%Y%m%d-%H%M%S).log"

run() {
  echo "==> $*" | tee -a "$log_file"
  "$@" 2>&1 | tee -a "$log_file"
}

# Core app charts
run d helm upgrade --install account-pages ./charts/account-pages -n default --reuse-values
# run d helm upgrade --install webapp ./charts/webapp -n default --reuse-values
run d helm upgrade --install team-settings ./charts/team-settings -n default --reuse-values

# Infra/deps charts
run d helm upgrade --install cassandra-external ./charts/cassandra-external -n default --reuse-values
run d helm upgrade --install databases-ephemeral ./charts/databases-ephemeral -n default --reuse-values
run d helm upgrade --install demo-smtp ./charts/demo-smtp -n default --reuse-values
run d helm upgrade --install elasticsearch-external ./charts/elasticsearch-external -n default --reuse-values
run d helm upgrade --install fake-aws ./charts/fake-aws -n default --reuse-values
run d helm upgrade --install ingress-nginx-controller ./charts/ingress-nginx-controller -n default --reuse-values
run d helm upgrade --install minio-external ./charts/minio-external -n default --reuse-values

# Requires explicit tls.privateKey settings in 5.25.0 chart
run d helm upgrade --install nginx-ingress-services ./charts/nginx-ingress-services -n default --reuse-values \
  --set tls.privateKey.rotationPolicy=Always \
  --set tls.privateKey.algorithm=ECDSA \
  --set tls.privateKey.size=384

# Reaper chart needs explicit kubectl image config
run d helm upgrade --install reaper ./charts/reaper -n default --reuse-values \
  --set image.registry=docker.io \
  --set image.repository=bitnamilegacy/kubectl \
  --set image.tag=1.32.4

# cert-manager
run d helm upgrade --install cert-manager ./charts/cert-manager -n cert-manager-ns --reuse-values

run d helm list -A

echo "Done. Log: $log_file"
