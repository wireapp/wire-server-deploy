variable "name" {
  description = "VPC name as appearing in AWS"
}

variable "environment" {
  default     = "dev"
  description = "Environment name, as appears in the environment definition"
}

variable "dhcp_options_domain_name" {
  default     = "internal.vpc"
  description = "TODO"
}
