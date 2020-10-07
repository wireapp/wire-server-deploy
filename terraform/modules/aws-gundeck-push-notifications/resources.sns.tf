# Create platform applications for iOS and Android.

locals {

  # NOTE: Well, well, well, we got ourselves yet another 'bug' - or more precisely - an unexpected
  #       behaviour. One would think, that
  #
  #           concat(var.ios_applications, var.android_applications)
  #
  #       would be the plausible choice for this task, but no, here comes Terraform.
  #       'Hold my beer', it says: https://github.com/hashicorp/terraform/issues/26090
  #       tl;dr It eats all the fields that are NOT part of the items's intersection
  #       because different types. Admittedly, a reasonable explanation, but unexpected
  #       nonetheless. In order to work around it, we are pulling out the iron.
  applications = flatten([var.ios_applications, var.android_applications])

  # NOTE: What is a platform? AWS lingua for all the different push notification services (see comment in the resource)
  #       This nested iteration replaces each entry of 'applications' with a list of application <-> platform
  #       combinations and adds the 'platform' field to each of them
  # EXAMPLE:
  #  [
  #    [
  #      {
  #        id = "com.myapp"
  #        platform = "APNS"
  #        platforms = ["APNS","APNS_VOIP"]
  #        key = "REDACTED"
  #        cert = "REDACTED"
  #      },
  #      {
  #        id = "com.myapp"
  #        platform = "APNS_VOIP"
  #        platforms = ["APNS","APNS_VOIP"]
  #        key = "REDACTED"
  #        cert = "REDACTED"
  #      }
  #    ],
  #    [
  #      {
  #        id = "123456789"
  #        platform = "GCM"
  #        platforms = ["GCM"]
  #        key = "REDACTED"
  #        cert = "REDACTED"
  #      }
  #    ]
  #  ]
  #
  app_platforms_lists = [
    for _, app in local.applications : [
      for _, platform in app.platforms : merge(app, { platform = platform })
    ]
  ]

  # NOTE: get rid of the nested lists being generated
  flattened_app_platforms_list = flatten(local.app_platforms_lists)

  # NOTE: converts in to a map with the following identifier syntax: '${id}-${platform}'
  #       for each application <-> platform combination
  # EXAMPLE:
  #  {
  #    "com.myapp-APNS" = {
  #      id = "com.myapp"
  #      platform = "APNS"
  #      platforms = ["APNS","APNS_VOIP"]
  #      key = "REDACTED"
  #      cert = "REDACTED"
  #    },
  #    ...
  #  }
  #
  app_platforms_map = {
    for _, app_platform in local.flattened_app_platforms_list
      : "${app_platform.id}-${app_platform.platform}" => app_platform
  }

}

resource "aws_sns_platform_application" "apps" {
  for_each = local.app_platforms_map

  # The name of the app is IMPORTANT! If it does not follow the pattern, then apps will not be able
  # to register for push notifications
  # [iOS] More details: https://github.com/zinfra/backend-wiki/wiki/Native-Push-Notifications#ios
  # [Android] More details: https://github.com/zinfra/backend-wiki/wiki/Native-Push-Notifications#android
  #
  name = "${var.environment}-${each.value.id}"
  # ^-- [iOS] <env>-<bundleID>
  # ^-- [Android] <env>-<projectID>
  #  <env> should match the env on gundeck's config
  #  <bundleID> name of the application, which is bundled/hardcoded when the app is built
  #  <projectID> name of the firebase project (this is unique across all firebase projects)

  # NOTE: possible values https://docs.aws.amazon.com/sns/latest/dg/sns-message-attributes.html#sns-attrib-mobile-reserved
  platform = each.value.platform

  platform_credential = each.value.key
  # ^-- [iOS] Content of to the private key
  # ^-- [Android] Content of the secret token
  platform_principal = lookup(each.value, "cert", null)
  # ^-- [iOS] Content of the public certificate

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
