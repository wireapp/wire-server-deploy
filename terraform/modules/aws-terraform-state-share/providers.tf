# NOTE: the provider assums that the respective environemnt variables,
# reuqired for authentication, already being set
#
provider "aws" {
  version = "~> 2.58"

  region = var.region
}
