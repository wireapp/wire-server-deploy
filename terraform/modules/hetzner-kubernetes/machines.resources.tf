resource "hcloud_server" "machines" {
  for_each = { for m in var.machines: "${m.group_name}-${m.machine_id}" => m }

  name        = "${var.cluster_name}-${each.key}"
  location    = var.default_location
  image       = var.default_image
  server_type = lookup(each.value, "machine_type", var.default_server_type)
  ssh_keys    = var.ssh_keys

  # NOTE: string is the only accepted type
  # DOCS: for possible characters, see https://docs.hetzner.cloud/#labels
  labels = merge(
    {
      cluster = var.cluster_name
      group_name = each.value.group_name
      machine_id = each.value.machine_id
    },
    contains( each.value.component_classes, "controlplane" ) ? { etcd_member_name = "etcd-${ each.value.machine_id }" } : {},
    { for class in each.value.component_classes : "component-class.${local.LABEL_PREFIX}/${class}" => true }
  )
}


resource "hcloud_server_network" "snw" {
  for_each = toset([ for m in var.machines: "${m.group_name}-${m.machine_id}" ])

  server_id = hcloud_server.machines[each.key].id
  subnet_id = hcloud_network_subnet.sn.id
}


resource "hcloud_volume" "volumes" {
  for_each = {
    for m in var.machines:
      "${m.group_name}-${m.machine_id}" => m
      if contains(keys(m), "volume")
  }

  name = "vol-${ var.cluster_name }-${ each.value.group_name }-${ each.value.machine_id }"
  size = each.value.volume.size
  automount = contains(keys(each.value.volume), "format")
  format = contains(keys(each.value.volume), "format") ? each.value.volume.format : null

  server_id = hcloud_server.machines[each.key].id

  labels = merge(
    {
      cluster = var.cluster_name
      group_name = each.value.group_name
      attached_to = each.value.machine_id
    },
    contains( each.value.component_classes, "controlplane" ) ? { etcd_member_name = "etcd-${ each.value.machine_id }" } : {}
  )
}
