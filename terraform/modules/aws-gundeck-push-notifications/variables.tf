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
variable "ios_applications" {
  type = list(object({
    id        = string # iOS application name (aka app ID), e.g. 'wire.com'
    platforms = list(string)
    key       = string # docs: https://www.terraform.io/docs/providers/aws/r/sns_platform_application.html#platform_credential
    cert      = string # docs: https://www.terraform.io/docs/providers/aws/r/sns_platform_application.html#platform_principal
  }))
  description = "list of iOS applications and their credentials to be registered for push notifications (SNS)"
}


# Check https://github.com/zinfra/backend-wiki/wiki/Native-Push-Notifications#android
variable "android_applications" {
  type = list(object({
    id        = string # Android application name (aka sender ID), e.g. '482078210000'
    platforms = list(string)
    key       = string # docs: https://www.terraform.io/docs/providers/aws/r/sns_platform_application.html#platform_credential
  }))
  description = "list of iOS applications and their credentials to be registered for push notifications (SNS)"
}


variable "queue_name" {
  type        = string
  description = "name of the queue to fetch events from (prefix: $environment)"
  default     = "gundeck-events"
}
