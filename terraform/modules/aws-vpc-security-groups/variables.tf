variable "vpc_id" {
  type        = string
  description = "ID of VPC these security groups are for."
}

variable "s3_CIDRs" {
  type        = list(string)
  description = "subnets that S3 gateways we are using exist in."
}

