variable "cluster_name" {
  type = string
}

variable "default_image" {
  type = string
  default = "ubuntu-18.04"
}

variable "default_server_type" {
  type = string
  default = "cx51"
}

variable "ssh_keys" {
  type = set(string)
}

variable "default_location" {
  type = string
  default = "nbg1"
}

variable "node_count"  {
  type = number
}
