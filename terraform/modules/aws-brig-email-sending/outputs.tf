# Output required to configure wire-server

output "ses_endpoint" {
  value = "https://email.${var.region}.amazonaws.com"
}

output "brig_access_key" {
  value = aws_iam_access_key.brig.id
}

output "brig_access_secret" {
  value = aws_iam_access_key.brig.secret
}