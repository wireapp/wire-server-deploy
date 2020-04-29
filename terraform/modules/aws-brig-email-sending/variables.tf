variable "region" {
  type        = string
  description = "defines in which region state and lock are being stored (default: 'eu-central-1')"
  default     = "eu-central-1"
}

variable "environment" {
  type        = string
  description = "name of the environment as a scope for the created resources (default: 'dev'; example: 'prod', 'staging')"
  default     = "dev"
}

variable "email_domain" {
  type        = string
  description = "FQDN of the email address that is used in 'From' when sending emails (example: example.com)"
}

variable "zone_id" {
  type = string
  description = "zone ID defined by a 'aws_route53_zone.zone_id' resource (example: Z12345678SQWERTYU"
}

variable "email_sender" {
  type        = string
  description = "username of the email address that is used in 'From' when sending emails (default: `no-reply`)"
  default = "no-reply"
}
