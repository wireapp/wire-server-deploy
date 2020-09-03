variable "environment" {
  type        = string
  description = "name of the environment as a scope for the created resources (default: 'dev'; example: 'prod', 'staging')"
  default     = "dev"
}

variable "node_port_http" {
  type        = number
  description = "HTTP port on the target machines that the LB forwards ingress from port 80 to"
  default     = 8080
}

variable "node_port_https" {
  type        = number
  description = "HTTPS port on the target machines that the LB forwards ingress from port 443 to"
  default     = 8443
}

variable "node_ips" {
  type        = list(string)
  description = "a list of private IPs from all nodes the load balancer forwards traffic to"
}

variable "subnet_ids" {
  type        = list(string)
  description = "a list of IDs from subnets where the nodes are part of, and the load balancer egress is attached to"
}

variable "aws_vpc_id" {
  type        = string
  description = "the ID of the VPC we are adding our targets to."
}
