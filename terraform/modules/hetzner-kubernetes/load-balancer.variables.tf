variable "lb_port_mappings" {
  description = "list of ports the load balancer is being configured with"
  type = list(object({
    name = string
    protocol = string
    listen = number
    destination = number
  }))
  default = [
    {
      name = "http"
      protocol = "tcp"
      listen = 80
      destination = 8080  # OR: 31772
    },
    {
      name = "https"
      protocol = "tcp"
      listen = 443
      destination = 8443  # OR: 31772
    },
    {
      name = "kube-api"
      protocol = "tcp"
      listen = 6443
      destination = 6443
    }
  ]
}
