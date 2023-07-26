#!/usr/bin/env bash

set -euo pipefail

helm upgrade --install --wait cassandra-external ./charts/cassandra-external --values ./values/cassandra-external/values.yaml
helm upgrade --install --wait elasticsearch-external ./charts/elasticsearch-external --values ./values/elasticsearch-external/values.yaml
helm upgrade --install --wait minio-external ./charts/minio-external --values ./values/minio-external/values.yaml
helm upgrade --install --wait fake-aws ./charts/fake-aws --values ./values/fake-aws/prod-values.example.yaml
helm upgrade --install --wait demo-smtp ./charts/demo-smtp --values ./values/demo-smtp/prod-values.example.yaml
helm upgrade --install --wait databases-ephemeral ./charts/databases-ephemeral --values ./values/databases-ephemeral/prod-values.example.yaml
helm upgrade --install --wait reaper ./charts/reaper
helm upgrade --install --wait --timeout=15m0s wire-server ./charts/wire-server --values ./values/wire-server/prod-values.example.yaml --values ./values/wire-server/secrets.yaml
echo "Printing all pods status"
kubectl get pods --all-namespaces -o wide
helm upgrade --install ingress-nginx-controller ./charts/ingress-nginx-controller --values ./values/ingress-nginx-controller/prod-values.example.yaml
#./bin/debug_logs.sh
# TODO: Requires certs; which we do not have in CI/CD at this point. future work =) (Would need cert-manager in offline package. That'd be neat)
# helm upgrade --install --wait nginx-ingress-services ./charts/nginx-ingress-services --values ./values/nginx-ingress-services/values.yaml  --values ./values/nginx-ingress-services/secrets.yaml
