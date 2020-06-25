Terraform module: Network load balancer
=======================================

State: __experimental__

This module creates a network load balancer for HTTP (port 80) and HTTPS (port 443) traffic.
It uses a *target group* for each port and attaches all instances that share the given *role*
to each group. It furthermore uses the given target ports to check their health.

Load balancing happens across availability zones. The VPC is determined by the given environment.
The subnets used within the VPC are assumed to

a) have an internet gateway
b) are tagged with `Routability:public`
c) be attached to the machines tagged with the `target_role`


*Please note, in order for this to work, ingress has to be allowed on the given target ports for all target machines.* 

AWS resources: lb (type: network)


#### How to use the module

```hcl
module "nlb" {
  source = "github.com/wireapp/wire-server-deploy.git//terraform/modules/aws-network-load-balancer?ref=develop"
  
  environment = "staging"

  target_role = "myEphemeralAppNode"
  http_target_port = 3000
  https_target_port = 3001
}
```
