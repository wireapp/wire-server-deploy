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
