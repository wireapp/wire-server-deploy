terraform {
  required_version = "0.13.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.28"
    }
    hcloud = {
      source  = "terraform-providers/hcloud"
      version = "~> 1.19"
    }
  }
}
