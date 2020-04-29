Terraform module: Gundeck Push Notifications
============================================

State: __experimental__

This module enables Push Notifications for iOS and Android devices. It is used by Gundeck when running in an AWS cloud.

AWS resources: SQS, SNS


#### Important note

This module causes Terraform to store sensitive data in the `.tfstate` file. Hence, encrypting the state should be
mandatory.


#### How to use the module

```hcl
module "gundeck-push-notification" {
  source = "github.com/wireapp/wire-server-deploy.git//terraform/modules/aws-gundeck-push-notifications?ref=develop"
  
  environment = "dev"
  apns_application_id = "myapp.tld"
  apns_key = file("path/to/app-credentials/key.pem")
  apns_cert = file("path/to/app-credentials/cert.pem")
  gcm_application_id = "123456789"
  gcm_key = file("path/to/app-credentials/key.txt")
}
```

Outputs are used in [wire-server chart values](https://github.com/wireapp/wire-server-deploy/blob/a55d17afa5ac2f40bd50c5d0b907f60ac028377a/values/wire-server/prod-values.example.yaml#L121)
