terraform {
  required_version = "0.13.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.58"
    }
    hcloud = {
      source  = "terraform-providers/hcloud"
      version = "~> 1.19"
    }
    local = {
      source = "hashicorp/local"
      version = "~> 1.4.0"
    }
  }

  backend s3 {
    encrypt = true
  }

}
