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
  type        = string
  description = "Name of the bucket that cargohold uses to store files (default: 'assets'; prefix: $environment) "
  default     = "assets"
}

variable "vpc_id" {
  type        = string
  description = "the ID of the VPC to add an S3 endpoint to"
}

variable "route_table_ids" {
  type        = list(string)
  description = "list of the route table IDs to associate the S3 endpoint with."
  default     = []
}
