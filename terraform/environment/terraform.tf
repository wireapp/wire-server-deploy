terraform {
  required_version = "0.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.58"
    }
    hcloud = {
      source  = "terraform-providers/hcloud"
      version = "~> 1.19"
    }
  }

  backend s3 {
    encrypt = true
  }

}
