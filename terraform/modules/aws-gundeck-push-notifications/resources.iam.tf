resource "aws_iam_user" "gundeck" {
  name          = "${var.environment}-gundeck-full-access"
  force_destroy = true
}

resource "aws_iam_access_key" "gundeck" {
  user = aws_iam_user.gundeck.name
}

# Create a specific user that can be used to publish messages to the given SNS applications
# and to consume messages from the SQS queues
#
resource "aws_iam_user_policy" "gundeck" {
  count = length(aws_sns_platform_application.apps) > 0 ? 1 : 0

  name = "${var.environment}-gundeck-full-access-policy"
  user = aws_iam_user.gundeck.name

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
                  "${aws_sqs_queue.push_notifications.arn}"
              ]
          },
          {
              "Effect": "Allow",
              "Action": [
                  "sns:CreatePlatformEndpoint",
                  "sns:DeleteEndpoint",
                  "sns:GetEndpointAttributes",
                  "sns:GetPlatformApplicationAttributes",
                  "sns:SetEndpointAttributes",
                  "sns:Publish"
              ],
              "Resource": ${jsonencode(
                [for _, v in aws_sns_platform_application.apps : v.arn]
              )}
          }
      ]
  }
  EOP
}
