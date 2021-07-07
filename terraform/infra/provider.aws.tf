variable "aws_region" {
  default = "eu-central-1"
}

provider "aws" {
  region = var.aws_region
}
