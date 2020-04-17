variable "prekey_table_name" {
  description = "E.g., prod-prekeys. Table used to store userID.clientID mappings"
  type = string
}

variable "prekey_table_read_capacity" {
  description = "E.g., 100. How many reads/sec allowed on the table."
  type = number
}

variable "prekey_table_write_capacity" {
  description = "E.g., 100. How many writes/sec allowed on the table."
  type = number
}

variable "internal_queue_name" {
  description = "E.g., prod-internal-queue. Name of the queue to be used for internal events such as user deletion"
  type = string
}

variable "email_sender" {
  description = "E.g., test@example.com. The sender email address"
  type = string
}

variable "ses_queue_name" {
  description = "E.g., prod-email-events-queue. Name of the queue where bounces/complaints emails are sent to"
  type = string
}

# Make certain AWS attributes available

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# FUTUREWORK: How to make sure we are operating on the account we want to?

# Potentially look at autoscaling for dynamoDB: https://www.terraform.io/docs/providers/aws/r/appautoscaling_policy.html

resource "aws_dynamodb_table" "prekey_table" {
  name           = "${var.prekey_table_name}"
  billing_mode   = "PROVISIONED" # default value
  read_capacity  = "${var.prekey_table_read_capacity}"
  write_capacity = "${var.prekey_table_write_capacity}"
  hash_key       = "client"

  attribute {
    name = "client"
    type = "S"
  }
}

# Create queues for internal events

resource "aws_sqs_queue" "internal_events_queue" {
  name = "${var.internal_queue_name}"
}

# Email section

resource "aws_sqs_queue" "email_events_queue" {
  name = "${var.ses_queue_name}"
}

resource "aws_ses_email_identity" "email_sender_identity" {
  email = "${var.email_sender}"
}

# By convention, we use the same name for the topic and the queue name

resource "aws_sns_topic" "sns_topic_ses_notifications" {
  name = "${var.ses_queue_name}"
}

resource "aws_ses_identity_notification_topic" "ses_notification_topic_bounce" {
  topic_arn                = "${aws_sns_topic.sns_topic_ses_notifications.arn}"
  notification_type        = "Bounce"
  identity                 = "${aws_ses_email_identity.email_sender_identity.arn}"
  include_original_headers = false
}

resource "aws_ses_identity_notification_topic" "ses_notification_topic_complaint" {
  topic_arn                = "${aws_sns_topic.sns_topic_ses_notifications.arn}"
  notification_type        = "Complaint"
  identity                 = "${aws_ses_email_identity.email_sender_identity.arn}"
  include_original_headers = false
}

resource "aws_sns_topic_subscription" "email_feedback_subscription" {
  topic_arn = aws_sns_topic.sns_topic_ses_notifications.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.email_events_queue.arn
  raw_message_delivery = true
}

# Ensure that the SNS topic is allowed to publish messages to the SQS queue

resource "aws_sqs_queue_policy" "allow_sns_updates_on_the_queue" {
  queue_url = "${aws_sqs_queue.email_events_queue.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "${aws_sqs_queue.email_events_queue.arn}/SQSDefaultPolicy",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": "SQS:SendMessage",
      "Resource": "${aws_sqs_queue.email_events_queue.arn}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${aws_sns_topic.sns_topic_ses_notifications.arn}"
        }
      }
    }
  ]
}
POLICY
}

# Create a specific user that can be used to access DynamoDB, SQS and SES

resource "aws_iam_user_policy" "brig-full-access-policy" {
  name = "brig-full-access-policy"
  user = "${aws_iam_user.brig-full-access.name}"

  policy = <<EOF
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
                "${aws_dynamodb_table.prekey_table.arn}"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "sqs:DeleteMessage",
                "sqs:GetQueueUrl",
                "sqs:ReceiveMessage",
                "sqs:SendMessage"
            ],
            "Resource": [
                "${aws_sqs_queue.internal_events_queue.arn}"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "sqs:DeleteMessage",
                "sqs:GetQueueUrl",
                "sqs:ReceiveMessage"
            ],
            "Resource": [
                "${aws_sqs_queue.email_events_queue.arn}"
            ]
        },
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
EOF
}

resource "aws_iam_user" "brig-full-access" {
  name = "brig-full-access"
  force_destroy = true
}

resource "aws_iam_access_key" "brig-full-access-credentials" {
  user = "${aws_iam_user.brig-full-access.name}"
}

# Output required to configured wire-server

output "region" {
  value = "${data.aws_region.current.name}"
}
output "prekeyTable" {
  value = "${aws_sqs_queue.internal_events_queue.name}"
}
output "internalQueue" {
  value = "${aws_sqs_queue.internal_events_queue.name}"
}
output "sesQueue" {
  value = "${aws_sqs_queue.email_events_queue.name}"
}
output "emailSender" {
  value = "${var.email_sender}"
}
output "sesEndpoint" {
  value = "https://email.${data.aws_region.current.name}.amazonaws.com"
}
output "sqsEndpoint" {
  value = "https://sqs.${data.aws_region.current.name}.amazonaws.com"
}
output "dynamoDBEndpoint" {
  value = "https://dynamodb.${data.aws_region.current.name}.amazonaws.com"
}
output "brig-secrets-awsKeyId" {
  value = "${aws_iam_access_key.brig-full-access-credentials.id}"
}
# This value is sensitive in nature and you cannot get it later.
output "brig-secrets-awsSecretKey" {
  value = "${aws_iam_access_key.brig-full-access-credentials.secret}"
}
