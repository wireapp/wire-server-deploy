Terraform module: Brig pre-key locking, event queue (optional: email sending)
=============================================================================

State: __experimental__

This module allows wire-server's brig service to leverage AWS resources (A) to
acquire a lock using dynamoDB (used during insertion and retrieval of prekeys
in cassandra to avoid race conditions), and (B) to establish a message queue
for internal events (used e.g. during user deletions).

[Optional] Wire-server's "brig" components needs to send emails. This can either
be done by configuring an SMTP server (Option 1), or by using AWS resources (Option 2).
This terraform module can enable brig to send emails using option 2. In addition, it
configures *MAIL FROM* for outgoing emails, but does not enable incoming emails
(possible solution: `aws_ses_receipt_rule`).

AWS resources: SQS, DynamoDB, (optionally: SES, SNS, DNS)


#### Important note

This module causes Terraform to store sensitive data in the `.tfstate` file. Hence, encrypting the state should be
mandatory.


#### How to use the module

##### With email sending __enabled__

```hcl
module "brig_prekey_lock_and_event_queue_emailing" {
  source = "github.com/wireapp/wire-server-deploy.git//terraform/modules/aws-brig-prekey-lock-event-queue-email-sending?ref=CHANGE-ME"

  environment = "staging"

  zone_id = "Z12345678SQWERTYU"
  domain = "example.com"
}
```

##### With email sending __disabled__

```hcl
module "brig_prekey_lock_and_event_queue" {
  source = "github.com/wireapp/wire-server-deploy.git//terraform/modules/aws-brig-prekey-lock-event-queue-email-sending?ref=CHANGE-ME"

  environment = "staging"
  enable_email_sending = false    # default: true
}
```

Outputs are used in [wire-server chart values](https://github.com/wireapp/wire-server-deploy/blob/a55d17afa5ac2f40bd50c5d0b907f60ac028377a/values/wire-server/prod-values.example.yaml#L27)
