terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    hcloud = {
      source = "hetznercloud/hcloud"
    }
  }
  required_version = "~> 1.1"
}
