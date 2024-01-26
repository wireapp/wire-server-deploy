terraform {
  required_version = "~> 1.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.58"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
    }
  }

  backend s3 {
    encrypt = true
  }

}
