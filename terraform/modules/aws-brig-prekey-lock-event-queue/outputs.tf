# Output required to configure wire-server

output "sqs_endpoint" {
  value = "https://sqs.${var.region}.amazonaws.com"
}

output "dynamodb_endpoint" {
  value = "https://dynamodb.${var.region}.amazonaws.com"
}

output "brig_access_key" {
  value = aws_iam_access_key.brig.id
}

output "brig_access_secret" {
  value = aws_iam_access_key.brig.secret
}
