Terraform module: Brig to enable email sending
==============================================

State: __experimental__

Wire-server's "brig" components needs to send emails. This can either be done by configuring an
SMTP server (Option 1), or by using AWS resources (Option 2).

This terraform module enables brig to send emails using option 2.

AWS resources: SES, SQS, SNS, DNS


#### Important note

This module causes Terraform to store sensitive data in the `.tfstate` file. Hence, encrypting the state should be
mandatory.


#### How to use the module

```hcl
module "bring_email_sending" {
  source = "github.com/wireapp/wire-server-deploy.git//terraform/modules/aws-brig-email-sending?ref=develop"
  
  environment = "staging"
  sender_address = "no-reply@example.com"
}
```

Outputs are used in [wire-server chart values](https://github.com/wireapp/wire-server-deploy/blob/a55d17afa5ac2f40bd50c5d0b907f60ac028377a/values/wire-server/prod-values.example.yaml#L27)
