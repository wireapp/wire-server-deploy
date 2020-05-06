Terraform module: instantiate and manage a group of AWS EC2 instances 
=====================================================================

State: __experimental__


#### How to use the module

##### Module instances required to exist 

```hcl
variable "environment" {
  type        = string
  description = "name of the environemnt of this state"
}

module "vpc" {
  source = "github.com/wireapp/wire-server-deploy.git//terraform/modules/aws-vpc?ref=tf-module_aws-machines"
  name        = var.environment
  environment = var.environment
}

module "security_groups" {
  source = "github.com/wireapp/wire-server-deploy.git//terraform/modules/aws-vpc-security-groups?ref=tf-module_aws-machines"
  vpc_id = module.vpc.vpc_id
}
```

##### Instantiate machines

```hcl
module "machines" {
  source = "github.com/wireapp/wire-server-deploy.git//terraform/modules/aws-machines?ref=tf-module_aws-machines"

  region = "eu-central-1"

  environment = var.environment
  type = "m5.large"
  role = "mytestrole"

  image = {
    filter = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"
    owner = "099720109477"  # Canonical
    hypervisor = "hvm"
  }
  volume_size = 20

  security_groups = [
    module.security_groups.talk_to_assets,
    module.security_groups.has_ssh,
    module.security_groups.k8s_private,
    module.security_groups.talk_to_stateful,
    module.security_groups.k8s_node
  ]

  instances = [
    {
      name = "mymachine1",
      subnet = module.vpc.private_subnets[1]
    },
    {
      name = "mymachine3",
      subnet = module.vpc.private_subnets[1]
    },
    {
      name = "mymachine2",
      subnet = module.vpc.private_subnets[0]
    }
  ]
}
```
