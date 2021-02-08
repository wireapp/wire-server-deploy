module "hetzner_kubernetes" {
  count =  min(1, var.kubernetes_node_count)

  source = "../modules/hetzner-kubernetes"

  cluster_name = var.environment
  default_server_type = var.kubernetes_server_type
  ssh_keys = local.hcloud_ssh_keys
  node_count = var.kubernetes_node_count
}
