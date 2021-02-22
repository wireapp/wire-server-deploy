# NOTE: this is just an example, including ./../interfaces/bucket-aws

variable "bucket_aws" {
  type = list(any)
  default = []
}


module "bucket_aws_instances" {
  for_each = { for k,v in var.bucket_aws : v.name => v }
  source = "./../interfaces/bucket-aws"

  name = each.value.name

  is_public = try(each.value.is_public, false)
}
