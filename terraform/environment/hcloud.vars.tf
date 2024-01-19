variable "hcloud_image" {
  default = "ubuntu-22.04"
}

variable "hcloud_location" {
  default = "nbg1"
}

variable "operator_ssh_public_keys" {
  type = object({
    terraform_managed = map(string) # Map of key name to the public key content
    preuploaded_key_names = set(string)
  })
  validation {
    condition = (
      length(var.operator_ssh_public_keys.terraform_managed) > 0 ||
      length(var.operator_ssh_public_keys.preuploaded_key_names) > 0
      )
    error_message = "At least one key must be provided."
  }
}
