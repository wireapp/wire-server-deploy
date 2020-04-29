# Output required to configure wire-server

output "bucket_name" {
  value = aws_s3_bucket.asset_storage.bucket
}

output "s3_endpoint" {
  value = "https://s3.${aws_s3_bucket.asset_storage.region}.amazonaws.com"
}

output "cargohold_access_key" {
  value = aws_iam_access_key.cargohold.id
}

output "cargohold_access_secret" {
  value = aws_iam_access_key.cargohold.secret
}