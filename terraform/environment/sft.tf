variable "sft_servers" {
  default = []
  type = list(string)
}

variable "sft_a_record_ttl" {
  default = 60
}

variable "sft_server_type" {
  default = "cx11"
}

module "sft" {
  count = min(1, length(var.sft_servers))

  source = "../modules/sft"
  root_domain = var.root_domain
  environment = var.environment
  sft_servers = var.sft_servers
  a_record_ttl = var.sft_a_record_ttl
  server_type = var.sft_server_type
  image = var.hcloud_image
  location = var.hcloud_location
  ssh_keys = [hcloud_ssh_key.operator_ssh.name]
}
