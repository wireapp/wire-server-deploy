variable "lb_port_mappings" {
  description = "list of ports the load balancer is being configured with"
  type = list(object({
    name = string
    protocol = string
    listen = number
    destination = number
  }))
  default = []
}
