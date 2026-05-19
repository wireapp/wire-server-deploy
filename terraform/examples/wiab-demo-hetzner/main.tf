locals {
}

variable "location" {
  description = "Hetzner location selected by the deployment script"
  type        = string
  default     = "hel1"
}

variable "server_type" {
  description = "Server type selected by the deployment script"
  type        = string
  default     = "cx53"
}

# Get available server types and locations
data "hcloud_server_types" "available" {}
data "hcloud_datacenters" "available" {}

locals {
  available_server_type_names = [for st in data.hcloud_server_types.available.server_types : st.name]
  available_location_names    = [for dc in data.hcloud_datacenters.available.datacenters : dc.location.name]
}

resource "null_resource" "location_validation" {
  count = contains(local.available_location_names, var.location) ? 0 : 1

  provisioner "local-exec" {
    command = <<-EOT
      echo "DEPLOYMENT FAILED: Requested location is unavailable"
      echo "Requested location: ${var.location}"
      echo "Available locations: ${join(", ", local.available_location_names)}"
      echo "Please check Hetzner Cloud region availability"
      exit 1
    EOT
  }
}

resource "null_resource" "server_type_validation" {
  count = contains(local.available_server_type_names, var.server_type) ? 0 : 1

  provisioner "local-exec" {
    command = <<-EOT
      echo "DEPLOYMENT FAILED: Requested server type is currently unavailable"
      echo "Requested server type: ${var.server_type}"
      echo "Available types: ${join(", ", local.available_server_type_names)}"
      echo "Please check server type availability"
      exit 1
    EOT
  }
}

resource "null_resource" "deployment_info" {
  depends_on = [
    null_resource.location_validation,
    null_resource.server_type_validation
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "VALIDATION PASSED: Deploying WIAB dev infrastructure"
      echo "Location: ${var.location}"
      echo "Server type: ${var.server_type}"
    EOT
  }
}

resource "random_pet" "host" {
  depends_on = [null_resource.deployment_info]
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
  location    = var.location
  name        = "host-${random_pet.host.id}"
  image       = "ubuntu-24.04"
  ssh_keys    = [hcloud_ssh_key.host.name]
  server_type = var.server_type

}
