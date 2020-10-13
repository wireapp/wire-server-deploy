locals {
  // This duplication is bad, but terraform doesn't allow defining functions.
  map_server_name_to_type_green = {for _, server_name in  var.server_groups.green.server_names: server_name => var.server_groups.green.server_type}
  map_server_name_to_type_blue = {for _, server_name in var.server_groups.blue.server_names : server_name => var.server_groups.blue.server_type}
  map_server_name_to_type = merge(local.map_server_name_to_type_blue, local.map_server_name_to_type_green)
}


resource "hcloud_server" "sft" {
  for_each = local.map_server_name_to_type

  name = "${var.environment}-sft-${each.key}"
  server_type = each.value
  image = var.image
  location = var.location
  ssh_keys = var.ssh_keys
}
