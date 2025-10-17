locals {
  # Server type preferences with fallbacks
  preferred_server_types = {
    size = ["cx53", "cpx62"]  }
}

# Get available server types in the specified location
data "hcloud_server_types" "available" {
}

# Helper locals to select available server types
locals {
  available_server_type_names = [for st in data.hcloud_server_types.available.server_types : st.name]

  # Select the first available server type from the preference list
  server_type = [
    for preferred in local.preferred_server_types.size :
    preferred if contains(local.available_server_type_names, preferred)
  ][0]
}

resource "random_pet" "host" {
}

resource "tls_private_key" "host" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "hcloud_ssh_key" "host" {
  name       = "host-${random_pet.host.id}"
  public_key = tls_private_key.host.public_key_openssh
}

resource "hcloud_server" "host" {
  location    = "nbg1"
  name        = "host-${random_pet.host.id}"
  image       = "ubuntu-24.04"
  ssh_keys    = [hcloud_ssh_key.host.name]
  server_type = local.server_type

}
