# Output required to configure wire-server

output "notification_queue_name" {
  value = aws_sqs_queue.push_notifications.name
}

output "sqs_endpoint" {
  value = "https://sqs.${var.region}.amazonaws.com"
}

output "sns_endpoint" {
  value = "https://sns.${var.region}.amazonaws.com"
}

output "gundeck_access_key" {
  value = aws_iam_access_key.gundeck.id
}

# This value is sensitive in nature and you cannot be obtained from AWS console.
# However, it is stored in the Terraform state, like all outputs, and can be
# queried with `terraform output`.
output "gundeck_access_secret" {
  value = aws_iam_access_key.gundeck.secret
}
