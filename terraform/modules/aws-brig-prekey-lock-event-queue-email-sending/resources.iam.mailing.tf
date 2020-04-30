resource "aws_iam_user_policy" "allow_brig_to_queue_email_events" {
  count = local.emailing_enabled

  name = "${var.environment}-brig-email-events-queue-policy"
  user = aws_iam_user.brig.name

  policy = <<-EOP
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Action": [
                  "sqs:DeleteMessage",
                  "sqs:GetQueueUrl",
                  "sqs:ReceiveMessage"
              ],
              "Resource": [
                  "${aws_sqs_queue.email_events[0].arn}"
              ]
          }
      ]
  }
  EOP
}

resource "aws_iam_user_policy" "allow_brig_to_send_emails" {
  count = local.emailing_enabled

  name = "${var.environment}-brig-send-emails-policy"
  user = aws_iam_user.brig.name

  policy = <<-EOP
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Action": [
                  "ses:SendEmail",
                  "ses:SendRawEmail"
              ],
              "Resource": [
                  "*"
              ]
          }
      ]
  }
  EOP
}
