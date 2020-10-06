variable "root_domain" {
  type = string
}

variable "environment" {
  type = string
}

variable "server_names" {
  description = "List of names of sft servers. The server will be availables at sft<name>.<environment>.<root_domain>"
  type = set(string)
}

variable "server_names_stale" {
  #TODO: Make this better
  description = "List of names of stale sft servers. The server will be availables at sft<name>.<environment>.<root_domain>, ideally these shouldn't be touched by terraform"
  type = set(string)
}

variable "a_record_ttl" {
  type = number
}

variable "metrics_srv_record_ttl" {
  default = 60
}

variable "server_type" {
  default = "cx11"
}

variable "server_type_stale" {
  default = "cx11"
}

variable "image" {
  default = "ubuntu-18.04"
}

variable "location" {
  default = "nbg1"
}

variable "ssh_keys" {
  type = list
}
