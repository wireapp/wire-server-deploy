resource "aws_iam_user" "brig" {
  name          = "${var.environment}-brig-email-sending"
  force_destroy = true
}

resource "aws_iam_access_key" "brig" {
  user = aws_iam_user.brig.name
}

resource "aws_iam_user_policy" "allow_brig_to_queue_email_events" {
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
                  "${aws_sqs_queue.email_events.arn}"
              ]
          }
      ]
  }
  EOP
}

resource "aws_iam_user_policy" "allow_brig_to_send_emails" {
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
