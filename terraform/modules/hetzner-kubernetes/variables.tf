variable "environment" {
  type = string
}

variable "image" {
  default = "ubuntu-18.04"
}

variable "server_type" {
  type = string
}

variable "ssh_keys" {
  type = set(string)
}

variable "location" {
  default = "nbg1"
}

variable "node_count"  {
  type = number
}
