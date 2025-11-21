# Offline Inventory Configuration

Ansible inventory for offline/air-gapped deployments of Wire infrastructure.

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


## Documentation

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
ansible -i ansible/inventory/offline/hosts.ini all -m ping
```
