# Output required to configure wire-server

output "sqs_endpoint" {
  value = "https://sqs.${data.aws_region.current}.amazonaws.com"
}

output "dynamodb_endpoint" {
  value = "https://dynamodb.${data.aws_region.current}.amazonaws.com"
}

output "brig_access_key" {
  value = aws_iam_access_key.brig.id
}

output "brig_access_secret" {
  value = aws_iam_access_key.brig.secret
}
