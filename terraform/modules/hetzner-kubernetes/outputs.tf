output "ips" {
  value = var.with_load_balancer ? [ hcloud_load_balancer.lb[0].ipv4 ] : [
    for _, machine in hcloud_server.machines : machine.ipv4_address
      if contains( keys(machine.labels), "component-class.${local.LABEL_PREFIX}/node" )
    ]
}
