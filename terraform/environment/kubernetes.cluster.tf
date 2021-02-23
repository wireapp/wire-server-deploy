locals {
  machines = flatten([
    for g in try(var.k8s_cluster.machine_groups, []) : [
      for mid in range(1, 1 + lookup(g, "machine_count", 1)) : merge(
        # NOTE: destruct group configuration and removing 'machine_count'
        { for k,v in g : k => v if k != "machine_count" },
        { machine_id = format("%02d", mid) }
      )
    ]
  ])
  # NOTE: set 'with_load_balancer' to true if not defined but LB ports are defined, thus 'load_balancer' may become optional
  load_balancer_is_used = lookup(var.k8s_cluster, "load_balancer", length(lookup(var.k8s_cluster, "load_balancer_ports", [])) > 0)
}

module "hetzner_k8s_cluster" {
  for_each = toset(try(var.k8s_cluster.cloud == "hetzner", false) ? [var.environment] : [])

  source = "./../modules/hetzner-kubernetes"

  cluster_name = each.key
  machines = local.machines
  ssh_keys = local.hcloud_ssh_keys
  with_load_balancer = local.load_balancer_is_used
  lb_port_mappings = lookup(var.k8s_cluster, "load_balancer_ports", [])
}
