locals {
  map_server_name_to_type_stale = {for _, server_name in  var.server_names_stale: server_name => var.server_type_stale}
  map_server_name_to_type_fresh = {for _, server_name in var.server_names : server_name => var.server_type}
  map_server_name_to_type = merge(local.map_server_name_to_type_stale, local.map_server_name_to_type_fresh)
}


resource "hcloud_server" "sft" {
  for_each = local.map_server_name_to_type

  name = "${var.environment}-sft-${each.key}"
  server_type = each.value
  image = var.image
  location = var.location
  ssh_keys = var.ssh_keys
}
