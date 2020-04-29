resource "aws_ses_domain_identity" "brig" {
  domain = var.domain
}

resource "aws_ses_email_identity" "brig" {
  email = "${var.sender_email_username}@${var.domain}"
}

resource "aws_ses_domain_dkim" "brig" {
  domain = aws_ses_domain_identity.brig.domain
}

resource "aws_ses_domain_mail_from" "brig" {
  domain           = aws_ses_domain_identity.brig.domain
  mail_from_domain = "${var.from_subdomain}.${var.domain}"
}


resource "aws_ses_identity_notification_topic" "bounce" {
  topic_arn                = aws_sns_topic.email_notifications.arn
  notification_type        = "Bounce"
  identity                 = aws_ses_email_identity.brig.arn
  include_original_headers = false
}

resource "aws_ses_identity_notification_topic" "complaint" {
  topic_arn                = aws_sns_topic.email_notifications.arn
  notification_type        = "Complaint"
  identity                 = aws_ses_email_identity.brig.arn
  include_original_headers = false
}
