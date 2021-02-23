resource "hcloud_load_balancer" "lb" {
  count = var.with_load_balancer ? 1 : 0

  name     = "${var.cluster_name}-lb"
  location = var.default_location

  load_balancer_type = (
    length(var.machines) <= 5 ? "lb11" : (
    length(var.machines) <= 75 ? "lb21" : (
    length(var.machines) <= 150 ? "lb31" : null))
  )

  # NOTE: not sure what impact the fact has that one LB targets two possibly
  #       disjunct groups of machines and what role the algo play in that
  algorithm {
    type = "round_robin"
  }
}


resource "hcloud_load_balancer_network" "lb-nw" {
  count = var.with_load_balancer ? 1 : 0

  load_balancer_id = hcloud_load_balancer.lb[0].id
  network_id       = hcloud_network.nw.id
}


resource "hcloud_load_balancer_service" "svcs" {
  for_each = var.with_load_balancer ? merge(
    { for pm in local.LB_PORT_MAPPINGS : pm.name => pm },
    { for pm in var.lb_port_mappings : pm.name => pm }
  ) : {}

  load_balancer_id = hcloud_load_balancer.lb[0].id

  protocol         = each.value.protocol
  listen_port      = each.value.listen
  destination_port = each.value.destination

  health_check {
    port     = each.value.destination
    protocol = "tcp"
    interval = 15
    retries  = 3
    timeout  = 6
  }
}


resource "hcloud_load_balancer_target" "controlplanes" {
  count = var.with_load_balancer ? 1 : 0

  type = "label_selector"

  label_selector = "component-class.${local.LABEL_PREFIX}/controlplane"
  use_private_ip = true

  load_balancer_id = hcloud_load_balancer.lb[0].id

  # NOTE: prevent race condition
  # ISSUE: https://github.com/hetznercloud/terraform-provider-hcloud/issues/170
  depends_on = [hcloud_load_balancer_network.lb-nw]
}


resource "hcloud_load_balancer_target" "nodes" {
  count = var.with_load_balancer ? 1 : 0

  type = "label_selector"

  label_selector = "component-class.${local.LABEL_PREFIX}/node"
  use_private_ip = true

  load_balancer_id = hcloud_load_balancer.lb[0].id

  # NOTE: prevent race condition
  # ISSUE: https://github.com/hetznercloud/terraform-provider-hcloud/issues/170
  depends_on = [hcloud_load_balancer_network.lb-nw]
}
