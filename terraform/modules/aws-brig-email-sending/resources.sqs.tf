resource "aws_sqs_queue" "email_events" {
  name = "${var.environment}-brig-email-events"
}

# Ensure that the SNS topic is allowed to publish messages to the SQS queue

resource "aws_sqs_queue_policy" "allow_email_notification_events" {
  queue_url = aws_sqs_queue.email_events.id

  policy = <<-EOP
  {
      "Version": "2012-10-17",
      "Id": "${aws_sqs_queue.email_events.arn}/SQSDefaultPolicy",
      "Statement": [
          {
              "Effect": "Allow",
              "Principal": {
                 "AWS": "*"
              },
              "Action": "SQS:SendMessage",
              "Resource": "${aws_sqs_queue.email_events.arn}",
              "Condition": {
                  "ArnEquals": {
                      "aws:SourceArn": "${aws_sns_topic.email_notifications.arn}"
                  }
              }
          }
      ]
  }
  EOP
}

