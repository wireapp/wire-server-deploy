variable "environment" {
  type        = string
  description = "name of the environment as a scope for the created resources (default: 'dev'; example: 'prod', 'staging')"
  default     = "dev"
}

variable "node_port_http" {
  type        = number
  description = "HTTP port from the target machines that the LB forwards ingress on port 80 to"
  default     = 8080
}

variable "node_port_https" {
  type        = number
  description = "HTTPS port from the target machines that the LB forwards ingress on port 443 to"
  default     = 8443
}

variable "node_ips" {
  type        = list(string)
  description = "a list of private IPs from all nodes the load balancer forwards traffic to"
}

variable "subnet_ids" {
  type        = list(string)
  description = "a list of IDs from subnets where the nodes are connected to"
}
