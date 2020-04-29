# NOTE: the provider assums that the respective environemnt variables,
# reuqired for authentication, are being set in parent module
#
provider "aws" {
  version = "~> 2.58"

  region = var.region
}
