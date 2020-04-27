variable "region" {
  type        = string
  description = "defines in which region state and lock are being stored"
  default     = "eu-central-1"
}

variable "environment" {
  type        = string
  description = "name of the environment as a scope for the created resources (e.g., prod. Can be staging or anything else)"
  default     = "dev"
}

variable "account_id" {
  type        = string
  description = "AWS account the created resources are need to be assigned to"
}

# Check https://github.com/zinfra/backend-wiki/wiki/Native-Push-Notifications#ios
variable "apns_application_id" {
  type        = string
  description = "iOS application name (aka app ID), e.g. 'wire.com'"
}

variable "apns_credentials_path" {
  type        = string
  description = "path to certificate and private key files (omit '.[cert,key].pem')"
}

# Check https://github.com/zinfra/backend-wiki/wiki/Native-Push-Notifications#android
variable "gcm_application_id" {
  type        = string
  description = "Android application name (aka sender ID), e.g. '482078210000'"
}

variable "gcm_credentials_path" {
  type        = string
  description = "path to the key file (omit '.key.txt')"
}


variable "queue_name" {
  type        = string
  description = "name of the queue to fetch events from"
  default     = "gundeck-push-notifications"
}
