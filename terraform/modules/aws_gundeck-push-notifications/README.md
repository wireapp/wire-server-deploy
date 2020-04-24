Terraform module: Gundeck Push Notifications
============================================

This module enables Push Notifications for iOS and Android devices. It is used by Gundeck when running in an AWS cloud.


#### How to use the module

```hcl-terraform
module "gundeck-push-notification" {
  source = "github.com/wireapp/wire-server-deploy.git//terraform/modules/aws_gundeck-push-notifications?ref=develop"
  
  region = "eu-central-1"
  environment = "dev"
  account_id = ""
  apns_application_id = "wire.com"
  apns_credentials_path = "${path.root}/path/to/app-credentials/files"   # omit '.[cert,key].pem'
  gcm_application_id = "123456789"
  gcm_credentials_path = "${path.root}/path/to/app-credentials/file"     # omit '.key.txt'
}
```
