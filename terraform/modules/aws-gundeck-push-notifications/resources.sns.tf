resource "aws_sns_platform_application" "ios" {
  for_each = toset(var.ios_applications)

  # The name of the app is IMPORTANT! If it does not follow the pattern, then apps will not be able
  # to register for push notifications
  # More details: https://github.com/zinfra/backend-wiki/wiki/Native-Push-Notifications#ios
  name = "${var.environment}-${each.value.id}"
  # ^-- <env>-<bundleID>
  #  <env> should match the env on gundeck's config
  #  <bundleID> name of the application, which is bundled/hardcoded when the app is built
  # NOTE: possible values https://docs.aws.amazon.com/sns/latest/dg/sns-message-attributes.html#sns-attrib-mobile-reserved
  platform = each.value.platform

  platform_credential = each.value.key
  # ^-- Content of to the private key
  platform_principal = each.value.cert
  # ^-- Content of the public certificate

  event_delivery_failure_topic_arn = aws_sns_topic.device_state_changed.arn
  # ^-- Topic to subscribe to
  event_endpoint_updated_topic_arn = aws_sns_topic.device_state_changed.arn
  # ^-- Topic to subscribe to
}

resource "aws_sns_platform_application" "android" {
  for_each = toset(var.android_applications)

  # The name of the app is IMPORTANT! If it does not follow the pattern, then apps will not be able
  # to register for push notifications
  # [Android] More details: https://github.com/zinfra/backend-wiki/wiki/Native-Push-Notifications#android
  name = "${var.environment}-${each.value.id}"
  # ^-- [Android] <env>-<projectID>
  #  <env> should match the env on gundeck's config
  #  <projectID> name of the firebase project (this is unique across all firebase projects)

  # NOTE: possible values https://docs.aws.amazon.com/sns/latest/dg/sns-message-attributes.html#sns-attrib-mobile-reserved
  platform = each.value.platform

  platform_credential = each.value.key
  # ^-- The access token

  event_delivery_failure_topic_arn = aws_sns_topic.device_state_changed.arn
  # ^-- Topic to subscribe to
  event_endpoint_updated_topic_arn = aws_sns_topic.device_state_changed.arn
  # ^-- Topic to subscribe to
}

# Create topics and queues to publish push notifications

resource "aws_sns_topic" "device_state_changed" {
  name = "${var.environment}-${var.queue_name}"
}

resource "aws_sns_topic_subscription" "platform_updates_subscription" {
  topic_arn            = aws_sns_topic.device_state_changed.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.push_notifications.arn
  raw_message_delivery = true
}
