# FUTUREWORK: replace 'any' by implementing https://www.terraform.io/docs/language/functions/defaults.html
#
variable "k8s_cluster" {
  description = "represents Kubernetes cluster"
  # type = object({
  #   cloud = string
  #   machine_groups = list(object({
  #     group_name = string
  #     machine_ids = list(string)
  #     machine_type = string
  #     component_classes = list(string)
  #     volume = optional(object({
  #       size = number
  #       format = optional(string)
  #     }))
  #   }))
  # })
  type = any
  default = {}
}
