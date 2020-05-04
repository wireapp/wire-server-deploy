resource "aws_ses_domain_identity" "brig" {
  count = local.emailing_enabled

  domain = var.domain
}

resource "aws_ses_email_identity" "brig" {
  count = local.emailing_enabled

  email = "${var.sender_email_username}@${var.domain}"
}

resource "aws_ses_domain_dkim" "brig" {
  count = local.emailing_enabled

  domain = aws_ses_domain_identity.brig[0].domain
}

resource "aws_ses_domain_mail_from" "brig" {
  count = local.emailing_enabled

  domain           = aws_ses_domain_identity.brig[0].domain
  mail_from_domain = "${var.from_subdomain}.${var.domain}"
}


resource "aws_ses_identity_notification_topic" "bounce" {
  count = local.emailing_enabled

  topic_arn                = aws_sns_topic.email_notifications[0].arn
  notification_type        = "Bounce"
  identity                 = aws_ses_email_identity.brig[0].arn
  include_original_headers = false
}

resource "aws_ses_identity_notification_topic" "complaint" {
  count = local.emailing_enabled

  topic_arn                = aws_sns_topic.email_notifications[0].arn
  notification_type        = "Complaint"
  identity                 = aws_ses_email_identity.brig[0].arn
  include_original_headers = false
}
