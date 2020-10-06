variable "sft_server_names" {
  default = []
  type = list(string)
}

variable "sft_server_names_stale" {
  default = []
  type = list(string)
}

variable "sft_a_record_ttl" {
  default = 60
}

variable "sft_server_type" {
  default = "cx11"
}

variable "sft_server_type_stale" {
  default = "cx11"
}

module "sft" {
  count = min(1, length(concat(var.sft_server_names_stale, var.sft_server_names)))

  source = "../modules/sft"
  root_domain = var.root_domain
  environment = var.environment
  server_names = var.sft_server_names
  a_record_ttl = var.sft_a_record_ttl
  server_type = var.sft_server_type
  image = var.hcloud_image
  location = var.hcloud_location
  ssh_keys = local.hcloud_ssh_keys
  server_names_stale = var.sft_server_names_stale
  server_type_stale = var.sft_server_type_stale
}
