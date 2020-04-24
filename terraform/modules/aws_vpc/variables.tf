variable "name" {
  type = string
  description = "VPC name as appearing in AWS"
}

variable "environment" {
  type = string
  description = "Environment name, as appears in the environment definition"
  default     = "dev"
}

variable "dhcp_options_domain_name" {
  type = string
  description = "domain name given by AWS to the instances over DHCP."
  default     = "internal.vpc"
}
