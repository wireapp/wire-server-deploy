resource "aws_sns_topic" "email_notifications" {
  count = local.emailing_enabled

  name = aws_sqs_queue.email_events[0].name
}

resource "aws_sns_topic_subscription" "notify_via_email" {
  count = local.emailing_enabled

  topic_arn            = aws_sns_topic.email_notifications[0].arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.email_events[0].arn
  raw_message_delivery = true
}
