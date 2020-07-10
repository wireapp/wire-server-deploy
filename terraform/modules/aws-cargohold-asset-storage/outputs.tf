# Output required to configure wire-server

output "bucket_name" {
  value = aws_s3_bucket.asset_storage.bucket
}

output "bucket_id" {
  value = aws_s3_bucket.asset_storage.id
}

output "s3_endpoint" {
  value = "https://s3.${aws_s3_bucket.asset_storage.region}.amazonaws.com"
}

output "s3_endpoint_CIDRs" {
  value = aws_vpc_endpoint.s3.cidr_blocks
}

output "s3_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}

output "cargohold_access_key" {
  value = aws_iam_access_key.cargohold.id
}

output "cargohold_access_secret" {
  value = aws_iam_access_key.cargohold.secret
}