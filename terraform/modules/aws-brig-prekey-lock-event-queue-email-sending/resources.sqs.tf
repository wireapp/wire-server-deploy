# Create queues for internal events

resource "aws_sqs_queue" "internal_events" {
  name = "${var.environment}-brig-events-internal"
}
