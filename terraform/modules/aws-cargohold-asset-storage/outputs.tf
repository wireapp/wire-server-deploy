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

output "s3_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}

output "cargohold_access_key" {
  value = aws_iam_access_key.cargohold.id
}

output "cargohold_access_secret" {
  value = aws_iam_access_key.cargohold.secret
}

output "talk_to_S3" {
  value = aws_security_group.talk_to_S3.id
}
