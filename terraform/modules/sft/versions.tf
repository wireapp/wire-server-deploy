terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    hcloud = {
      source = "terraform-providers/hcloud"
    }
  }
  required_version = ">= 0.13"
}
