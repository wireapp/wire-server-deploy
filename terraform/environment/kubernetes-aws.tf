variable "kubernetes_aws" {
  type = list(any)
  default = []
}


module "kubernetes_aws" {
  for_each = { for k,v in var.kubernetes_aws : v.name => v }
  source = "./../interfaces/kubernetes-aws"

  name = each.value.name

  node_pools = each.value.node_pools

  is_managed = try(each.value.is_managed, false)
}
