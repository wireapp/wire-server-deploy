#!/usr/bin/env bash
set -euo pipefail

nodes=(192.168.122.21 192.168.122.22 192.168.122.23)
log_dir=/home/demo/new/bin/tools/logs
mkdir -p "$log_dir"

stamp=$(date +%Y%m%d-%H%M%S)
log_file="$log_dir/cleanup-all-$stamp.log"

echo "Starting cleanup at $stamp" | tee -a "$log_file"

for node in "${nodes[@]}"; do
  echo "==> $node" | tee -a "$log_file"
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null demo@${node} \
    "python3 /home/demo/cleanup-containerd-images.py \
      --sudo \
      --kubectl-shell \
      --kubectl-cmd 'sudo kubectl --kubeconfig /etc/kubernetes/admin.conf' \
      --log-dir /home/demo/cleanup-logs \
      --audit-tag ${node} \
      --apply" | tee -a "$log_file"
  echo "" | tee -a "$log_file"
done

echo "Done. Log: $log_file" | tee -a "$log_file"
