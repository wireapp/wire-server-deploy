variable "enable_email_sending" {
  type        = bool
  description = "flag to either hand off email sending to AWS or not"
  default     = true
}

# NOTE: setting the default to `null` allows to omit this var when instantiating the module
#       while still forcing it to be set, when email sending is enabled
#
variable "zone_id" {
  type        = string
  description = "zone ID defined by a 'aws_route53_zone.zone_id' resource (example: Z12345678SQWERTYU)"
  default     = null
}
variable "domain" {
  type        = string
  description = "FQDN of the email address that is used in 'From' when sending emails (example: default.domain)"
  default     = null
}

# As to why configuring a MAIL FROM
# docs: https://docs.aws.amazon.com/ses/latest/DeveloperGuide/mail-from.html#mail-from-overview
#
variable "from_subdomain" {
  type        = string
  description = "subdomain that is prepended to domain and used to configue MAIL FROM for mails being sent"
  default     = "email"
}

variable "sender_email_username" {
  type        = string
  description = "username of the email address that is used in 'From' when sending emails (default: 'no-reply'; result: 'no-reply@$domain')"
  default     = "no-reply"
}
