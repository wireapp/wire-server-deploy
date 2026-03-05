#!/usr/bin/env bash

set -euo pipefail
echo "Printing all pods status"
kubectl get pods --all-namespaces
echo "------------------------------------"
namespaces="cert-manager-ns default"
echo "Namespaces = $namespaces"
for ns in $namespaces; do
    pods=$(kubectl get pods -n $ns -o=jsonpath='{.items[*].metadata.name}')
    echo "Pods in namespace: $ns = $pods"
    for pod in $pods; do
        echo "Logs for pod: $pod"
        kubectl logs --tail 30 --all-containers -n "$ns" "$pod" || true
        echo "Description for pod: $pod"
        kubectl describe pod -n "$ns" "$pod" || true
        echo "------------------------------------"
    done
done
