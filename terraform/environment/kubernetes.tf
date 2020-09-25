variable "kubernetes_node_count" {
  type = number
  default = 0
  validation {
    condition = (
      var.kubernetes_node_count == 0 ||
      var.kubernetes_node_count % 2 == 1
    )
    error_message = "The kubernetes_node_count must be 0 or an odd number. ETCD does not like even numbers."
  }
}

variable "kubernetes_server_type" {
  default = "cx51"
}

variable "kubernetes_ssh_keys" {
  type = set(string)
  default = []
}

module "hetzner_kubernetes" {
  count =  min(1, var.kubernetes_node_count)

  source = "../modules/hetzner-kubernetes"

  environment = var.environment
  root_domain = var.root_domain
  server_type = var.kubernetes_server_type
  ssh_keys = local.hcloud_ssh_keys
  node_count = var.kubernetes_node_count
}
