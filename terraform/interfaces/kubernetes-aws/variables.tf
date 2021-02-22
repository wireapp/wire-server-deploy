variable "name" {
  type = string
}

variable "node_pools" {
  type = list(object({
    name = string
    count = number
    machine_type = string
  }))
}

variable "is_managed" {
  type = bool
  default = false
}
