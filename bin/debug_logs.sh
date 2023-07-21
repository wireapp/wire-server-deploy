#!/usr/bin/env bash

set -euo pipefail

echo "Editing the configMap nodelocaldns -n kube-system"
CURRENT_COREFILE=$(kubectl get configmap nodelocaldns -n kube-system -o=jsonpath='{.data.Corefile}')
echo "Current Corefile:"
echo "$CURRENT_COREFILE"
MODIFIED_TEXT=$(echo "$CURRENT_COREFILE" | sed '/forward \. \/etc\/resolv\.conf/d')
echo "Modified Corefile:"
echo "$MODIFIED_TEXT"
kubectl create configmap nodelocaldns -n kube-system --from-literal="Corefile=$MODIFIED_TEXT" --dry-run=client -o yaml | kubectl apply -f -
echo "Printing kubectl describe configMap nodelocaldns -n kube-system after updating"
kubectl describe configMap nodelocaldns -n kube-system

echo "Printing kubectl describe configMap coredns -n kube-system"
kubectl describe configMap coredns -n kube-system
echo "Updating the configMap coredns -n kube-system"
kubectl get configmap coredns -n kube-system --output yaml > coredns_config.yaml
sed -i coredns_config.yaml -e '/^[ ]*forward.*/{N;N;N;d;}' -e "s/^\([ ]*\)cache/\1forward . 127.0.0.53:9999 {\n\1  max_fails 0\n\1}\n\1cache/"
kubectl apply -f coredns_config.yaml

sleep 10
pods=$(kubectl get pods -n kube-system -o=jsonpath='{.items[*].metadata.name}')
echo "Pods not running:"
echo "$pods"
for pod in $pods; do
    echo "Logs for pod: $pod"
    kubectl logs --all-containers -n kube-system "$pod" || true
    echo "------------------------------------"
done