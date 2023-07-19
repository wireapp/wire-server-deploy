#!/usr/bin/env bash

set -euo pipefail

pods=$(kubectl get pods -n kube-system --field-selector=status.phase!=Running,status.phase!=Completed -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
echo "Pods not running:"
echo "$pods"
for pod in $pods; do
    echo "Logs for pod: $pod"
    kubectl logs --all-containers -n kube-system "$pod"
    echo "------------------------------------"
done