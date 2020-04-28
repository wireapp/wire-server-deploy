resource "aws_iam_user" "brig" {
  name          = "${var.environment}-brig-prekeys-events"
  force_destroy = true
}

resource "aws_iam_access_key" "brig" {
  user = aws_iam_user.brig.name
}

resource "aws_iam_user_policy" "allow_brig_to_store_prekeys" {
  name = "${var.environment}-brig-prekeys-policy"
  user = aws_iam_user.brig.name

  policy = <<-EOP
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Action": [
                  "dynamodb:GetItem",
                  "dynamodb:PutItem",
                  "dynamodb:DeleteItem"
              ],
              "Resource": [
                  "${aws_dynamodb_table.prekeys.arn}"
              ]
          }
      ]
  }
  EOP
}

resource "aws_iam_user_policy" "allow_brig_to_queue_internal_events" {
  name = "${var.environment}-brig-internal-events-queue-policy"
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
                  "sqs:ReceiveMessage",
                  "sqs:SendMessage"
              ],
              "Resource": [
                  "${aws_sqs_queue.internal_events.arn}"
              ]
          }
      ]
  }
  EOP
}
