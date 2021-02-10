locals {
  machines = flatten([
    for g in var.k8s_cluster.machine_groups : [
      for mid in range(1, 1 + lookup(g, "machine_count", 1)) : merge(
        # NOTE: destruct group configuration and removing 'machine_count'
        { for k,v in g : k => v if k != "machine_count" },
        { machine_id = format("%02d", mid) }
      )
    ]
  ])
}

module "hetzner_k8s_cluster" {
  for_each = toset(var.k8s_cluster.cloud == "hetzner" ? [var.environment] : [])

  source = "./../modules/hetzner-kubernetes"

  cluster_name = each.key
  machines = local.machines
  with_load_balancer = lookup(var.k8s_cluster, "load_balancer", false)
  ssh_keys = local.hcloud_ssh_keys
}
