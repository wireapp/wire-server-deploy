locals {
  rfc1918_cidr        = "10.0.0.0/8"
  kubenode_count      = 3
  datanode_count      = 3
  ssh_keys            = [hcloud_ssh_key.adminhost.name]

  # Location preferences with fallbacks (EU only)
  preferred_locations = ["fsn1", "hel1", "nbg1"]

  # Server type preferences with fallbacks (optimized for availability)
  preferred_server_types = {
    small  = ["cx33", "cpx22", "cx43"] # For assethost and adminhost
    medium = ["cx43", "cx53", "cpx42"] # For datanodes and k8s_nodes
  }
}

# Get available server types and locations
data "hcloud_server_types" "available" {}
data "hcloud_datacenters" "available" {}

# Helper locals to select available resources with robust fallback logic
locals {
  available_server_type_names = [for st in data.hcloud_server_types.available.server_types : st.name]
  available_location_names    = [for dc in data.hcloud_datacenters.available.datacenters : dc.location.name]

  # Select the first available location from the preference list
  available_preferred_locations = [
    for preferred in local.preferred_locations :
    preferred if contains(local.available_location_names, preferred)
  ]
  selected_location = length(local.available_preferred_locations) > 0 ? local.available_preferred_locations[0] : null

  # Select the first available server type from the preference list (with validation)
  available_small_server_types = [
    for preferred in local.preferred_server_types.small :
    preferred if contains(local.available_server_type_names, preferred)
  ]
  small_server_type = length(local.available_small_server_types) > 0 ? local.available_small_server_types[0] : null

  available_medium_server_types = [
    for preferred in local.preferred_server_types.medium :
    preferred if contains(local.available_server_type_names, preferred)
  ]
  medium_server_type = length(local.available_medium_server_types) > 0 ? local.available_medium_server_types[0] : null
}

# Validation checks - fail early with helpful error messages
resource "null_resource" "location_validation" {
  count = local.selected_location != null ? 0 : 1

  provisioner "local-exec" {
    command = <<-EOT
      echo "DEPLOYMENT FAILED: No suitable location available"
      echo "Requested locations: ${join(", ", local.preferred_locations)}"
      echo "Available locations: ${join(", ", local.available_location_names)}"
      echo "Please check Hetzner Cloud region availability"
      exit 1
    EOT
  }
}

resource "null_resource" "small_server_type_validation" {
  count = local.small_server_type != null ? 0 : 1

  provisioner "local-exec" {
    command = <<-EOT
      echo "DEPLOYMENT FAILED: No suitable database server types available"
      echo "Requested types: ${join(", ", local.preferred_server_types.small)}"
      echo "Available types: ${join(", ", local.available_server_type_names)}"
      echo "Please check server type availability in the selected region"
      exit 1
    EOT
  }
}

resource "null_resource" "medium_server_type_validation" {
  count = local.medium_server_type != null ? 0 : 1

  provisioner "local-exec" {
    command = <<-EOT
      echo "DEPLOYMENT FAILED: No suitable Kubernetes server types available"
      echo "Requested types: ${join(", ", local.preferred_server_types.medium)}"
      echo "Available types: ${join(", ", local.available_server_type_names)}"
      echo "Please check server type availability in the selected region"
      exit 1
    EOT
  }
}

resource "null_resource" "deployment_info" {
  depends_on = [
    null_resource.location_validation,
    null_resource.small_server_type_validation,
    null_resource.medium_server_type_validation
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "VALIDATION PASSED: Deploying Wire offline infrastructure"
      echo "Location: ${local.selected_location}"
      echo "Database server type: ${local.medium_server_type}"
      echo "Kubernetes server type: ${local.medium_server_type}"
      echo "Total instances: ${local.datanode_count + local.kubenode_count + 2}"
    EOT
  }
}

resource "random_pet" "main" {
  depends_on = [null_resource.deployment_info]
}

resource "hcloud_network" "main" {
  name     = "main-${random_pet.main.id}"
  ip_range = cidrsubnet(local.rfc1918_cidr, 8, 1)
}

resource "hcloud_network_subnet" "main" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = cidrsubnet(hcloud_network.main.ip_range, 8, 1)
}


resource "random_pet" "adminhost" {
}

resource "tls_private_key" "admin" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "hcloud_ssh_key" "adminhost" {
  name       = "adminhost-${random_pet.adminhost.id}"
  public_key = tls_private_key.admin.public_key_openssh
}

# Connected to all other servers. Simulates the admin's "laptop"
resource "hcloud_server" "adminhost" {
  depends_on = [
    null_resource.deployment_info,
    hcloud_network_subnet.main
  ]
  location    = local.selected_location
  name        = "adminhost-${random_pet.adminhost.id}"
  image       = "ubuntu-22.04"
  ssh_keys    = local.ssh_keys
  server_type = local.small_server_type
  network {
    network_id = hcloud_network.main.id
    ip         = ""
  }
}

# The server hosting all the bootstrap assets
resource "random_pet" "assethost" {
}

resource "hcloud_server" "assethost" {
  depends_on = [
    null_resource.deployment_info,
    hcloud_network_subnet.main
  ]
  location    = local.selected_location
  name        = "assethost-${random_pet.assethost.id}"
  image       = "ubuntu-22.04"
  ssh_keys    = local.ssh_keys
  server_type = local.small_server_type
  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }
  network {
    network_id = hcloud_network.main.id
    ip         = ""
  }
}

resource "random_pet" "kubenode" {
  count = local.kubenode_count
}

resource "hcloud_server" "kubenode" {
  depends_on = [
    null_resource.deployment_info,
    hcloud_network_subnet.main
  ]
  count       = local.kubenode_count
  location    = local.selected_location
  name        = "kubenode-${random_pet.kubenode[count.index].id}"
  image       = "ubuntu-22.04"
  ssh_keys    = local.ssh_keys
  server_type = local.medium_server_type
  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }
  network {
    network_id = hcloud_network.main.id
    ip         = ""
  }
}

resource "random_pet" "datanode" {
  count = local.datanode_count
}

resource "hcloud_server" "datanode" {
  depends_on = [
    null_resource.deployment_info,
    hcloud_network_subnet.main
  ]
  count       = local.datanode_count
  location    = local.selected_location
  name        = "datanode-${random_pet.datanode[count.index].id}"
  image       = "ubuntu-22.04"
  ssh_keys    = local.ssh_keys
  server_type = local.medium_server_type
  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }
  network {
    network_id = hcloud_network.main.id
    ip         = ""
  }
}
