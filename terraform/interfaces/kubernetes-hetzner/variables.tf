variable "name" {
  type = string
}

variable "control_plane" {
  type = object({
    count = number
    is_worker = bool
    machine_type = string
  })
}

variable "node_pools" {
  type = list(object({
    name = string
    count = number
    machine_type = string
  }))
}

variable "with_load_balancer" {
  type = bool
  default = false
}

variable "load_balancer_ports" {
  type = list(object({
    name = string
    protocol = string
    listen = number
    destination = number
  }))
  default = []
}

variable "root_domain" {
  type = string
  default = null
}

variable "sub_domains" {
  type = list(string)
  default = []
}

variable "network_id" {
  type = string
  default = null
}

variable "subnet_id" {
  type = string
  default = null
}
