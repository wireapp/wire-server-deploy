Terraform module: Brig pre-key locking & event queue 
====================================================

State: __experimental__

This module allows Brig to leverage AWS resources (A) to lock pre-keys during insertion and
retrieval, and (B) to establish a message queue for internal events.

AWS resources: SQS, DynamoDB


#### Important note

This module causes Terraform to store sensitive data in the `.tfstate` file. Hence, encrypting the state should be
mandatory.


#### How to use the module

```hcl
module "bring_prekey_lock_and_event_queue" {
  source = "github.com/wireapp/wire-server-deploy.git//terraform/modules/aws-brig-prekey-lock-event-queue?ref=develop"
  
  environment = "staging"  
}
```

Outputs are used in [wire-server chart values](https://github.com/wireapp/wire-server-deploy/blob/a55d17afa5ac2f40bd50c5d0b907f60ac028377a/values/wire-server/prod-values.example.yaml#L27)
