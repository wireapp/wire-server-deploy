# Output required to configure wire-server

output "notification_queue_name" {
  value = aws_sqs_queue.push_notifications.name
}

output "sqs_endpoint" {
  value = "https://sqs.${data.aws_region.current.name}.amazonaws.com"
}

output "sns_endpoint" {
  value = "https://sns.${data.aws_region.current.name}.amazonaws.com"
}

output "gundeck_access_key" {
  value = aws_iam_access_key.gundeck.id
}

output "gundeck_access_secret" {
  value = aws_iam_access_key.gundeck.secret
}
