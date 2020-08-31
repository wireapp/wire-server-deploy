variable "hcloud_image" {
  default = "ubuntu-18.04"
}

variable "hcloud_location" {
  default = "nbg1"
}

provider "hcloud" {
  # NOTE: You must have a HCLOUD_TOKEN environment variable set!
}
