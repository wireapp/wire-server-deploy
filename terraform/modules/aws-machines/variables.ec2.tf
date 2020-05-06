variable "instances" {
  type = list(
    // NOTE: due to adequard sysntax implementation, we hav e to allow any structure and
    //       and do the defaulting where values are being used
    // see: https://github.com/hashicorp/terraform/issues/19898
    //
    map(any)
//  object({
//    name = string,     # NOTE: required; must be unique
//    type = string,
//    volume_size = string,
//    subnet = string
//  })
  )
  default = [ ]
}


variable "type" {
  type = string
  default = null
}

variable "subnet" {
  type = string
  default = null
}

variable "sshkey" {
  type = string
  default = null
}

variable "volume_size" {
  type = string
  default = null
}

variable "role" {
  type = string
  description = "sets the roles of the instances being created"
}

variable "security_groups" {
  type = list(string)
  description = "list of VPC security group references"
  default = []
}

variable "tags" {
  type = map(string)
  description = "map of AWS instance tags"
  default = {}
}