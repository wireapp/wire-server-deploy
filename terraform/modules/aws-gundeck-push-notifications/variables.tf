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


# Check https://github.com/zinfra/backend-wiki/wiki/Native-Push-Notifications#ios
variable "apns_application_id" {
  type        = string
  description = "iOS application name (aka app ID), e.g. 'wire.com'"
}

# docs: https://www.terraform.io/docs/providers/aws/r/sns_platform_application.html#platform_credential
variable "apns_key" {
  type        = string
  description = "content of the key file"
}

# docs: https://www.terraform.io/docs/providers/aws/r/sns_platform_application.html#platform_principal
variable "apns_cert" {
  type        = string
  description = "content of the cert file"
}


# Check https://github.com/zinfra/backend-wiki/wiki/Native-Push-Notifications#android
variable "gcm_application_id" {
  type        = string
  description = "Android application name (aka sender ID), e.g. '482078210000'"
}

# docs: https://www.terraform.io/docs/providers/aws/r/sns_platform_application.html#platform_credential
variable "gcm_key" {
  type        = string
  description = "content of the key file"
}


variable "queue_name" {
  type        = string
  description = "name of the queue to fetch events from (prefix: $environment)"
  default     = "gundeck-events"
}
