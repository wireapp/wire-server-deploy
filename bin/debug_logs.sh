#!/usr/bin/env bash

set -euo pipefail

echo "Printint d kubectl describe configMap coredns -n kube-system"
kubectl describe configMap coredns -n kube-system

echo "Printint d kubectl describe configMap nodelocaldns -n kube-system"
kubectl describe configMap nodelocaldns -n kube-system


pods=$(kubectl get pods -n kube-system -o=jsonpath='{.items[*].metadata.name}')
echo "Pods not running:"
echo "$pods"
for pod in $pods; do
    echo "Logs for pod: $pod"
    kubectl logs --all-containers -n kube-system "$pod" || true
    echo "------------------------------------"
done