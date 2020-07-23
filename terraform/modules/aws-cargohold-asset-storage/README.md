Terraform module: Cargohold Asset Storage
=========================================

State: __experimental__

This module creates an Object Storage on AWS for cargohold to store encrypted assets.

AWS resources: S3


#### Important note

This module causes Terraform to store sensitive data in the `.tfstate` file. Hence, encrypting the state should be
mandatory.


#### TODO

* [ ] add cloudfront support


#### How to use the module

```hcl
module "cargohold_asset_storage" {
  source = "github.com/wireapp/wire-server-deploy.git//terraform/modules/aws-cargohold-asset-storage?ref=CHANGE-ME"

  environment = "staging"
}
```

Outputs are used in [wire-server chart values](https://github.com/wireapp/wire-server-deploy/blob/a55d17afa5ac2f40bd50c5d0b907f60ac028377a/values/wire-server/prod-values.example.yaml#L95)
