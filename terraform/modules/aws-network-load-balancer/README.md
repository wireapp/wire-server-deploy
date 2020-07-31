Terraform module: Network load balancer
=======================================

State: __experimental__

This module creates a network load balancer for HTTP (port 80) and HTTPS (port 443) traffic.
It uses a *target group* for each port and attaches all instances that share the given *role*
to each group. It furthermore uses the given target ports to check their health.

Load balancing happens across availability zones. The VPC is determined by the given environment.
The subnets used within the VPC are assumed to

a) have an internet gateway
b) be attached to the machines referred to by IP via list of `node_ips``

*Please note, in order for this to work, ingress has to be allowed on the given target ports on all target machines.
Furthermore, since those target machines - referred to by IP - are not part of an auto-scaling group, the instance of
this module has to be re-applied every time the set of machines changes.* 

AWS resources: lb (type: network)

#### How to use the module

```hcl
module "nlb" {
  source = "github.com/wireapp/wire-server-deploy.git//terraform/modules/aws-network-load-balancer?ref=CHANGE-ME"
  
  environment = "staging"

  node_ips = ["10.0.23.17", "10.0.42.78", "10.0.222.171"]
  subnet_ids = ["subnet-0001", "subnet-0002", "subnet-0003"]

  http_target_port = 3000
  https_target_port = 3001
}
```

One way to generate the IPs and subnets lists would be to refer to the respective resources, or
attributes of another resource (e.g. VPC). Alternatively, you may want to obtain those lists
with the help of some data sources, e.g.

```hcl
data "aws_subnet_ids" "public" {
  vpc_id = var.vpc_id

  filter {
    name   = "tag:Environment"
    values = ["staging"]
  }

  filter {
    name   = "tag:Routability"
    values = ["public"]
  }
}


data "aws_instances" "nodes" {
  filter {
    name   = "tag:Environment"
    values = ["staging"]
  }

  filter {
    name   = "tag:Role"
    values = [ "kubenode" ]
  }

  instance_state_names = ["running"]
}
```