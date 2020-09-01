variable "hcloud_image" {
  default = "ubuntu-18.04"
}

variable "hcloud_location" {
  default = "nbg1"
}

variable "operator_ssh_public_key" {
  type = string
}

provider "hcloud" {
  # NOTE: You must have a HCLOUD_TOKEN environment variable set!
}

resource "hcloud_ssh_key" "operator_ssh" {
  name = "${var.environment}-operator"
  public_key = var.operator_ssh_public_key
}
