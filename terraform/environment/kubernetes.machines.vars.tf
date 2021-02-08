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
