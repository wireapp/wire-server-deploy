# Create platform applications for iOS and Android. At the moment, only VoIP is being used for iOS

resource "aws_sns_platform_application" "apns_voip" {
  name = "${var.environment}-${var.apns_application_id}"
  # ^-- <env>-<bundleID>
  #  <env> should match the env on gundeck's config
  #  <bundleID> name of the application, which is bundled/hardcoded when the app is built
  #
  # The name of the app is IMPORTANT! If it does not follow the pattern, then apps will not be able
  # to register for push notifications
  # More details: https://github.com/zinfra/backend-wiki/wiki/Native-Push-Notifications#ios
  #
  platform = "APNS_VOIP"
  # ^-- We only use VoIP at the moment
  platform_principal = var.apns_cert
  # ^-- Path to the public certificate
  platform_credential = var.apns_key
  # ^-- Path to the private key
  event_delivery_failure_topic_arn = aws_sns_topic.device_state_changed.arn
  # ^-- Topic to subscribe to
  event_endpoint_updated_topic_arn = aws_sns_topic.device_state_changed.arn
  # ^-- Topic to subscribe to
}

resource "aws_sns_platform_application" "gcm" {
  name = "${var.environment}-${var.gcm_application_id}"
  # ^-- <env>-<projectID>
  #
  # <env> should match the env on gundeck's config
  # <projectID> name of the firebase project (this is unique across all firebase projects)
  #
  # More details: https://github.com/zinfra/backend-wiki/wiki/Native-Push-Notifications#android
  #
  platform            = "GCM"
  platform_credential = var.gcm_key
  # ^-- Path to the secret token
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
