#!/usr/bin/env bash
set -euo pipefail

inventory=/home/demo/new/ansible/inventory/offline/hosts.ini
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
log_dir=/home/demo/new/bin/tools/logs
mkdir -p "$log_dir"

stamp=$(date +%Y%m%d-%H%M%S)
log_file="$log_dir/cleanup-all-$stamp.log"

echo "Starting cleanup at $stamp" | tee -a "$log_file"

for node in "${nodes[@]}"; do
  echo "==> $node" | tee -a "$log_file"
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
