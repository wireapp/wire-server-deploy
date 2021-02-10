variable "cluster_name" {
  type = string
}

variable "ssh_keys" {
  type = set(string)
}

variable "with_load_balancer" {
  description = "indicates whether a load balancer is being created and placed in front of all K8s machines"
  type = bool
  default = false
}
