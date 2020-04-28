Terraform module: Brig to enable email sending
==============================================

This module creates AWS resources (SES, SQS, SNS) enabling Brig to send emails.


#### How to use the module

```hcl-terraform
module "bring_email_sending" {
  source = "github.com/wireapp/wire-server-deploy.git//terraform/modules/aws-brig-email-sending?ref=develop"
  
  environment = "staging"
  sender_address = "no-reploy@wire.com"
}
```

Outputs are used in [wire-server chart values](https://github.com/wireapp/wire-server-deploy/blob/a55d17afa5ac2f40bd50c5d0b907f60ac028377a/values/wire-server/prod-values.example.yaml#L27)
