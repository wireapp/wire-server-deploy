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

variable "bucket_name" {
  type = string
  description = "Name of the bucket that cargohold uses to store files (default: 'assets'; prefix: $environment) "
  default = "assets"
}
