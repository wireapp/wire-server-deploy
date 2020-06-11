terraform {
  required_version = ">= 0.12.0"
}

# In AWS, (eu-central-1)
provider "aws" {
  region = "eu-central-1"
}

# Used for the in-VPC EC2 endpoint.
data "aws_security_group" "default" {
  name   = "default"
  vpc_id = module.vpc.vpc_id
}

module "vpc" {
  source = "github.com/terraform-aws-modules/terraform-aws-vpc?ref=v2.33.0"

  name = var.name

  cidr = "172.17.0.0/20"

  azs             = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  private_subnets = ["172.17.0.0/22", "172.17.4.0/22", "172.17.8.0/22"]
  public_subnets  = ["172.17.12.0/24", "172.17.13.0/24", "172.17.14.0/24"]

  enable_dns_hostnames = false
  enable_dns_support   = true

  enable_dhcp_options      = true
  dhcp_options_domain_name = var.dhcp_options_domain_name
  #  dhcp_options_domain_name_servers = 

  # In case we run terraform from within the environment.
  # VPC endpoint for DynamoDB
  enable_dynamodb_endpoint = true

  enable_s3_endpoint = true

  enable_nat_gateway     = true
  one_nat_gateway_per_az = false
  # Use this only in productionish environments.
  #  one_nat_gateway_per_az = true

  tags = {
    Owner       = "Backend Team"
    Environment = var.environment
  }
  vpc_tags = {
    Owner = "Backend Team"
    Name  = var.name
  }
}
