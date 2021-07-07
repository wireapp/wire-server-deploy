# module "kubernetes" {
#   count = var.is_managed ? 1 : 0
#   source = "./../../modules/aws-eks"
#   ...
# }
