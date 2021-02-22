variable "kubernetes_hetzner" {
  type = list(any)
  default = []
}


module "kubernetes_hetzner" {
  for_each = { for k,v in var.kubernetes_hetzner : v.name => v }
  source = "./../interfaces/kubernetes-hetzner"

  name = each.value.name

  control_plane = each.value.control_plane
  node_pools = each.value.node_pools

  with_load_balancer = try(each.value.with_load_balancer, false)
  load_balancer_ports = try(each.value.load_balancer_ports, [])
  root_domain = try(each.value.root_domain, null)
  sub_domains = try(each.value.sub_domains, [])
}
