# Output required to configure wire-server

output "ses_endpoint" {
  value = "https://email.${data.aws_region.current.name}.amazonaws.com"
}
