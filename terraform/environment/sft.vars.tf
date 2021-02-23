variable "sft_server_names_blue" {
  type = set(string)
  default = []
}

variable "sft_server_type_blue" {
  type = string
  default = "cx11"
}

variable "sft_server_names_green" {
  type = set(string)
  default = []
}

variable "sft_server_type_green" {
  type = string
  default = "cx11"
}

variable "sft_a_record_ttl" {
  default = 60
}
