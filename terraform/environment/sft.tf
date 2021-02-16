module "sft" {
  count = min(1, length(setunion(var.sft_server_names_blue, var.sft_server_names_green)))

  source = "../modules/sft"
  root_domain = var.root_domain
  environment = var.environment
  a_record_ttl = var.sft_a_record_ttl
  image = var.hcloud_image
  location = var.hcloud_location
  ssh_keys = local.hcloud_ssh_keys
  server_groups = {
    blue = {
      server_names = var.sft_server_names_blue
      server_type = var.sft_server_type_blue
    }
    green = {
      server_names = var.sft_server_names_green
      server_type = var.sft_server_type_green
    }
  }
}
