variable "root_domain" {
  type = string
  default = null
}

variable "sub_domains" {
  type = list(string)
  default = []
}

variable "create_spf_record" {
  type = bool
  default = false
}
