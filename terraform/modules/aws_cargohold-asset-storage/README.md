Terraform module: Cargohold Asset Storage
=========================================

This module creates an Object Storage on AWS for cargohold to store encrypted assets.


#### How to use the module

```hcl-terraform
module "gundeck-push-notification" {
  source = "github.com/wireapp/wire-server-deploy.git//terraform/modules/aws_cargohold-asset-storage?ref=develop"
  
  region = "eu-central-1"
  environment = "staging"
  account_id = "myAccountID"
  bucket_name = "my-assets"   # will be prefixed with $environment
}
```

Outputs are used in [wire-server chart values](https://github.com/wireapp/wire-server-deploy/blob/a55d17afa5ac2f40bd50c5d0b907f60ac028377a/values/wire-server/prod-values.example.yaml#L95)
