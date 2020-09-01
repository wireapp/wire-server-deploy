resource "hcloud_server" "sft" {
  for_each = var.sft_servers

  name = "${var.environment}-sft-${each.value}"
  server_type = var.server_type
  image = var.image
  location = var.location
  ssh_keys = var.ssh_keys
}
