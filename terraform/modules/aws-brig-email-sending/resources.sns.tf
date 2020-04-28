resource "aws_sns_topic" "email_notifications" {
  name = aws_sqs_queue.email_events.name
}

resource "aws_sns_topic_subscription" "notify_via_email" {
  topic_arn            = aws_sns_topic.email_notifications.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.email_events.arn
  raw_message_delivery = true
}
