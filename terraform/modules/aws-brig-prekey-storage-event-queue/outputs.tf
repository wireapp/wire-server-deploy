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

# This value is sensitive in nature and you cannot be obtained from AWS console.
# However, it is stored in the Terraform state, like all outputs, and can be
# queried with `terraform output`.
output "brig_access_secret" {
  value = aws_iam_access_key.brig.secret
}
