variable "region" {
  type        = string
  default     = "eu-central-1"
  description = "defines in which region state and lock are being stored"
}

variable "bucket_name" {
  type        = string
  description = "the name of the bucket, which needs to be globally unique"
}

variable "table_name" {
  type        = string
  description = "name of the DynamoDB table which holds the lock to accessing the terraform state"
}
