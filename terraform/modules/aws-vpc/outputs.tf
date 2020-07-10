output "vpc_id" {
  value = module.vpc.vpc_id
}

output "s3_endpoint_CIDRs" {
  value = aws_vpc_endpoint.s3.cidr_blocks
}

output "s3_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "private_subnets" {
  value = module.vpc.private_subnets
}
