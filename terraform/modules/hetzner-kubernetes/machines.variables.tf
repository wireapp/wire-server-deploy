variable "default_location" {
  default = "nbg1"
}

variable "default_server_type" {
  default = "cx51"
}

variable "default_image" {
  default = "ubuntu-18.04"
}


# FUTUREWORK: replace 'any' by implementing https://www.terraform.io/docs/language/functions/defaults.html
#
variable "machines" {
  description = "list of machines"
  # type = list(object({
  #   group_name = string
  #   machine_id = string
  #   machine_type = string
  #   component_classes = list(string)
  #   volume = optional(object({
  #     size = number
  #     format = optional(string)
  #   }))
  # }))
  type = any
  default = []

  validation {
    condition = length(var.machines) > 0
    error_message = "At least one machine must be defined."
  }
}
