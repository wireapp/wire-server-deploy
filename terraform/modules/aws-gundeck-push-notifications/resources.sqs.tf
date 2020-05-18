resource "aws_sqs_queue" "push_notifications" {
  name = "${var.environment}-${var.queue_name}"
}


# Ensure that the SNS topic is allowed to publish messages to the SQS queue

resource "aws_sqs_queue_policy" "allow_sns_push_notification_events" {
  queue_url = aws_sqs_queue.push_notifications.id

  policy = <<-EOP
  {
      "Version": "2012-10-17",
      "Id": "${aws_sqs_queue.push_notifications.arn}/SQSDefaultPolicy",
      "Statement": [
          {
              "Effect": "Allow",
              "Principal": {
                  "AWS": "*"
              },
              "Action": "SQS:SendMessage",
              "Resource": "${aws_sqs_queue.push_notifications.arn}",
              "Condition": {
                  "ArnEquals": {
                      "aws:SourceArn": "${aws_sns_topic.device_state_changed.arn}"
                  }
              }
          }
      ]
  }
  EOP
}
