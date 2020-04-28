Terraform module: Brig pre-key storage & event queue 
===================================================

This module creates AWS resources (SQS, DynamoDB) that allows Brig to store pre-keys on AWS and establishes a message
queue for internal events. 


#### How to use the module

```hcl-terraform
module "bring_prekey_storage_and_event_queue" {
  source = "github.com/wireapp/wire-server-deploy.git//terraform/modules/aws-brig-prekey-storage-event-queue?ref=develop"
  
  environment = "staging"  
}
```

Outputs are used in [wire-server chart values](https://github.com/wireapp/wire-server-deploy/blob/a55d17afa5ac2f40bd50c5d0b907f60ac028377a/values/wire-server/prod-values.example.yaml#L27)
