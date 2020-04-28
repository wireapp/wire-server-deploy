Terraform module: Cargohold Asset Storage
=========================================

This module creates an Object Storage on AWS for cargohold to store encrypted assets.

State: __experimental__

#### TODO

* [ ] add cloudfront support


#### How to use the module

```hcl
module "cargohold_asset_storage" {
  source = "github.com/wireapp/wire-server-deploy.git//terraform/modules/aws-cargohold-asset-storage?ref=develop"
  
  environment = "staging"
}
```

Outputs are used in [wire-server chart values](https://github.com/wireapp/wire-server-deploy/blob/a55d17afa5ac2f40bd50c5d0b907f60ac028377a/values/wire-server/prod-values.example.yaml#L95)
