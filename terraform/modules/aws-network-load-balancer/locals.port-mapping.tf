locals {
  port_mapping = {
    http = {
      protocol  = "TCP"
      port      = 80
      node_port = var.http_target_port
    },
    https = {
      protocol  = "TCP"
      port      = 443
      node_port = var.https_target_port
    }
  }
}
