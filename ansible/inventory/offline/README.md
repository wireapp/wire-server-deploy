# Offline Inventory Configuration

Ansible inventory for offline/air-gapped deployments of Wire infrastructure.

## Quick Start

### 1. Edit Inventory

```bash
# Define your hosts
vim ansible/inventory/offline/99-static

# Configure kube-vip HA (optional but recommended)
vim ansible/inventory/offline/group_vars/k8s-cluster/k8s-cluster.yml
```

### 2. Deploy

```bash
ansible-playbook -i ansible/inventory/offline ansible/kubernetes.yml
```

### 3. Access Cluster

```bash
export KUBECONFIG=ansible/inventory/offline/artifacts/admin.conf
kubectl get nodes
```

## Directory Structure

```
offline/
├── 99-static                      # Main inventory file
├── group_vars/
│   ├── all/offline.yml           # Base settings (k8s version, etc.)
│   ├── k8s-cluster/k8s-cluster.yml  # kube-vip HA configuration
│   ├── postgresql/postgresql.yml # PostgreSQL settings
│   └── demo/offline.yml          # Demo overrides
└── artifacts/                     # Generated (kubeconfig, etc.)
```

## Configuration Files

| File | Purpose |
|------|---------|
| `99-static` | Define hosts and group memberships |
| `group_vars/all/offline.yml` | Base settings (k8s version, container runtime) |
| `group_vars/k8s-cluster/k8s-cluster.yml` | kube-vip HA, API server, networking |
| `group_vars/postgresql/postgresql.yml` | PostgreSQL configuration |

## Key Variables to Customize

**In `99-static`:**
- Host IP addresses (`ansible_host` and `ip`)
- Node assignments to groups (`[kube-master]`, `[kube-node]`, `[etcd]`)

**In `group_vars/k8s-cluster/k8s-cluster.yml`:**
- `kube_vip_address` - Virtual IP for HA (e.g., `192.168.122.100`)
- `kube_vip_interface` - Network interface (e.g., `enp1s0`)

**In `group_vars/all/offline.yml`:**
- `kube_version` - Kubernetes version
- Network settings (usually defaults are fine)

## Common Tasks

### Deploy Full Cluster
```bash
ansible-playbook -i ansible/inventory/offline ansible/kubernetes.yml
```

### Add Node to Existing Cluster
```bash
# 1. Add node to 99-static
# 2. Run scale playbook
ansible-playbook -i ansible/inventory/offline \
  ansible/roles-external/kubespray/scale.yml
```

### Verify kube-vip HA
```bash
kubectl get pods -n kube-system | grep kube-vip
kubectl get lease -n kube-system plndr-cp-lock -o jsonpath='{.spec.holderIdentity}'
```

## Documentation

- **kube-vip HA Setup**: [../../../docs/kube-vip-ha-setup.md](../../../docs/kube-vip-ha-setup.md)
- **Kubespray**: https://github.com/kubernetes-sigs/kubespray
- **Wire Docs**: https://docs.wire.com/

## Important Notes

- VIP must be in same subnet as control plane nodes
- VIP must not be in DHCP range
- etcd requires odd number of members (3, 5, 7)
- Keep `artifacts/` directory secure (contains admin kubeconfig)
- For production, encrypt sensitive files with SOPS

## Troubleshooting

**Inventory not found:**
```bash
ansible-inventory -i ansible/inventory/offline --list
```

**Can't SSH to nodes:**
```bash
ansible -i ansible/inventory/offline all -m ping
```

**kube-vip not working:**
```bash
kubectl logs -n kube-system kube-vip-kubenode1
```

See [docs/kube-vip-ha-setup.md](../../../docs/kube-vip-ha-setup.md) for detailed troubleshooting.

---

**Last Updated**: 2024-11-19
