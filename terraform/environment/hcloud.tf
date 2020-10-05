variable "hcloud_image" {
  default = "ubuntu-18.04"
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

provider "hcloud" {
  # NOTE: You must have a HCLOUD_TOKEN environment variable set!
}

resource "hcloud_ssh_key" "operator_ssh" {
  for_each = var.operator_ssh_public_keys.terraform_managed
  name = each.key
  public_key = each.value
}

locals {
  hcloud_ssh_keys = concat(
    [for key in hcloud_ssh_key.operator_ssh: key.name],
    tolist(var.operator_ssh_public_keys.preuploaded_key_names)
    )
}
