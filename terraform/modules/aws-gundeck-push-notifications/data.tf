# NOTE: obtains region that is set in providers.tf by given variable
#
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}
