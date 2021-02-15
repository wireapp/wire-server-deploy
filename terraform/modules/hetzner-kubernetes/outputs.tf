output "ips" {
  value = var.with_load_balancer ? [ hcloud_load_balancer.lb[0].ipv4 ] : [
    for _, machine in hcloud_server.machines : machine.ipv4_address
      if contains( keys(machine.labels), "component-class.${local.LABEL_PREFIX}/node" )
    ]
}

# NOTE: the existence of this output feels indeed odd. What is generated here could and actually should
#       be done on the outside since 'machines' is already exposed. See ./../../environment/kubernetes.dns.tf
output "node_ips" {
  value = [
    for _, machine in hcloud_server.machines : machine.ipv4_address
      if contains( keys(machine.labels), "component-class.${local.LABEL_PREFIX}/node" )
  ]
}
