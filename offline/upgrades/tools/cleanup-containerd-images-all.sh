#!/usr/bin/env bash
set -euo pipefail

# This script runs cleanup-containerd-images.py on each kube node via SSH.
# The script automatically copies cleanup-containerd-images.py to each node before execution.

BUNDLE_ROOT=${WIRE_BUNDLE_ROOT:-/home/demo/wire-server-deploy-new}
cleanup_script=${BUNDLE_ROOT}/bin/tools/cleanup-containerd-images.py

if [ ! -f "$cleanup_script" ]; then
  echo "ERROR: Cleanup script not found at $cleanup_script" >&2
  exit 1
fi

inventory=${BUNDLE_ROOT}/ansible/inventory/offline/hosts.ini
mapfile -t nodes < <(
  awk '
    /^\[kube-master\]/ {section="kube-master"; next}
    /^\[kube-node\]/ {section="kube-node"; next}
    /^\[/ {section=""; next}
    section ~ /^kube-(master|node)$/ && $0 !~ /^#/ && NF>0 {
      host=$1
      for (i=2;i<=NF;i++) {
        if ($i ~ /^ansible_host=/) {
          split($i,a,"="); host=a[2]
        }
      }
      print host
    }
  ' "$inventory" | sort -u
)
if [ ${#nodes[@]} -eq 0 ]; then
  echo "No kube-master or kube-node hosts found in $inventory" >&2
  exit 1
fi
log_dir=${BUNDLE_ROOT}/bin/tools/logs
mkdir -p "$log_dir"

stamp=$(date +%Y%m%d-%H%M%S)
log_file="$log_dir/cleanup-all-$stamp.log"

echo "Starting cleanup at $stamp" | tee -a "$log_file"

for node in "${nodes[@]}"; do
  echo "==> $node" | tee -a "$log_file"

  # Copy cleanup script to remote node
  echo "Copying cleanup script to $node..." | tee -a "$log_file"
  scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "$cleanup_script" "demo@${node}:/home/demo/cleanup-containerd-images.py" 2>&1 | tee -a "$log_file"

  # Run cleanup on remote node
  ssh_cmd=(
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "demo@${node}"
    python3 /home/demo/cleanup-containerd-images.py
    --sudo
    --kubectl-shell
    --kubectl-cmd "sudo kubectl --kubeconfig /etc/kubernetes/admin.conf"
    --log-dir /home/demo/cleanup-logs
    --audit-tag "$node"
    --apply
  )
  "${ssh_cmd[@]}" | tee -a "$log_file"
  echo "" | tee -a "$log_file"
done

echo "Done. Log: $log_file" | tee -a "$log_file"
