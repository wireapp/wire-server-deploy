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

# NOTE: tweak to adjust performance/pricng ratio
# see: https://aws.amazon.com/dynamodb/pricing/provisioned/
#
variable "prekey_table_read_capacity" {
  type        = number
  description = "defines how many reads/sec allowed on the table (default: '10'; example: '100')"
  default     = 10
}
variable "prekey_table_write_capacity" {
  type        = number
  description = "defines how many writes/sec allowed on the table (default: '10'; example: '100')"
  default     = 10
}
