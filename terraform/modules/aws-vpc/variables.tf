variable "name" {
  type        = string
  description = "VPC name as appearing in AWS"
}

variable "environment" {
  type        = string
  description = "Environment name, as appears in the environment definition"
  default     = "dev"
}

variable "dhcp_options_domain_name" {
  type        = string
  description = "the default domain given to hosts in this VPC by the AWS DHCP servers"
  default     = "internal.vpc"
}
