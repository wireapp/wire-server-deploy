variable "root_domain" {
  type = string
}

variable "environment" {
  type = string
}

variable "server_groups" {
  description = <<EOD
    Names of sft servers divided between blue and green groups. Each group can
    contain an arbitrary set of servers names. There should be no servers which
    are in more than 1 group. These groups can be used to run upgrades on the
    SFT service. The server will be availables at
    sft<name>.<environment>.<root_domain>"
    EOD
  type = object({
    //Arbitrary name for the first group
    blue = object({
      server_names = set(string)
      server_type  = string
    })

    //Arbitrary name for the second group
    green = object({
      server_names = set(string)
      server_type  = string
    })
  })

  validation {
    condition = length(setintersection(var.server_groups.blue.server_names, var.server_groups.green.server_names)) == 0
    error_message = "The server_names in the blue and green server_groups must not intersect."
  }
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
