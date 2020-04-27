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

variable "bucket_name" {
  type = string
  description = "Name of the bucket that cargohold uses to store files, e.g. 'prod-assets'"
}
