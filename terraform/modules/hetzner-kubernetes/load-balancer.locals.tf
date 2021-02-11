locals {
  LB_PORT_MAPPINGS =  [
    {
      name = "http"
      protocol = "tcp"
      listen = 80
      destination = 8080
    },
    {
      name = "https"
      protocol = "tcp"
      listen = 443
      destination = 8443
    },
    {
      name = "kube-api"
      protocol = "tcp"
      listen = 6443
      destination = 6443
    }
  ]
}
