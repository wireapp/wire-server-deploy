locals {
  rfc1918_cidr        = "10.0.0.0/8"
  kubenode_count      = 3
  minio_count         = 2
  elasticsearch_count = 2
  cassandra_count     = 3
  postgresql_count    = 3
  rabbitmq_count      = 3
  ssh_keys            = [hcloud_ssh_key.adminhost.name]
}

variable "location" {
  description = "Hetzner location selected by the deployment script"
  type        = string
  default     = "hel1"
}

variable "small_server_type" {
  description = "Server type for cassandra, elasticsearch, minio, postgresql, and rabbitmq selected by the deployment script"
  type        = string
  default     = "cx23"
}

variable "medium_server_type" {
  description = "Server type for adminhost, assethost, and kubenode selected by the deployment script"
  type        = string
  default     = "cx33"
}

# Get available server types and locations
data "hcloud_server_types" "available" {}
data "hcloud_datacenters" "available" {}

# Validate the exact combination requested by the deployment script.
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

resource "null_resource" "small_server_type_validation" {
  count = contains(local.available_server_type_names, var.small_server_type) ? 0 : 1

  provisioner "local-exec" {
    command = <<-EOT
      echo "DEPLOYMENT FAILED: No suitable database server types available"
      echo "Requested small server type: ${var.small_server_type}"
      echo "Available types: ${join(", ", local.available_server_type_names)}"
      echo "Please check server type availability"
      exit 1
    EOT
  }
}

resource "null_resource" "medium_server_type_validation" {
  count = contains(local.available_server_type_names, var.medium_server_type) ? 0 : 1

  provisioner "local-exec" {
    command = <<-EOT
      echo "DEPLOYMENT FAILED: No suitable Kubernetes server types available"
      echo "Requested medium server type: ${var.medium_server_type}"
      echo "Available types: ${join(", ", local.available_server_type_names)}"
      echo "Please check server type availability"
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
      echo "VALIDATION PASSED: Deploying WSD default infrastructure"
      echo "Location: ${var.location}"
      echo "Database server type: ${var.small_server_type}"
      echo "Kubernetes server type: ${var.medium_server_type}"
      echo "Total instances: ${local.cassandra_count + local.postgresql_count + local.elasticsearch_count + local.minio_count + local.kubenode_count + 2}"
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
  location    = var.location
  name        = "adminhost-${random_pet.adminhost.id}"
  image       = "ubuntu-22.04"
  ssh_keys    = local.ssh_keys
  server_type = var.medium_server_type
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
  location    = var.location
  name        = "assethost-${random_pet.assethost.id}"
  image       = "ubuntu-22.04"
  ssh_keys    = local.ssh_keys
  server_type = var.medium_server_type
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
  location    = var.location
  name        = "kubenode-${random_pet.kubenode[count.index].id}"
  image       = "ubuntu-22.04"
  ssh_keys    = local.ssh_keys
  server_type = var.medium_server_type
  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }
  network {
    network_id = hcloud_network.main.id
    ip         = ""
  }
}

resource "random_pet" "cassandra" {
  count = local.cassandra_count
}

resource "hcloud_server" "cassandra" {
  depends_on = [
    null_resource.deployment_info,
    hcloud_network_subnet.main
  ]
  count       = local.cassandra_count
  location    = var.location
  name        = "cassandra-${random_pet.cassandra[count.index].id}"
  image       = "ubuntu-22.04"
  ssh_keys    = local.ssh_keys
  server_type = var.small_server_type
  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }
  network {
    network_id = hcloud_network.main.id
    ip         = ""
  }
}

resource "random_pet" "elasticsearch" {
  count = local.elasticsearch_count
}

resource "hcloud_server" "elasticsearch" {
  depends_on = [
    null_resource.deployment_info,
    hcloud_network_subnet.main
  ]
  count       = local.elasticsearch_count
  location    = var.location
  name        = "elasticsearch-${random_pet.elasticsearch[count.index].id}"
  image       = "ubuntu-22.04"
  ssh_keys    = local.ssh_keys
  server_type = var.small_server_type
  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }
  network {
    network_id = hcloud_network.main.id
    ip         = ""
  }
}

resource "random_pet" "minio" {
  count = local.minio_count
}

resource "hcloud_server" "minio" {
  depends_on = [
    null_resource.deployment_info,
    hcloud_network_subnet.main
  ]
  count       = local.minio_count
  location    = var.location
  name        = "minio-${random_pet.minio[count.index].id}"
  image       = "ubuntu-22.04"
  ssh_keys    = local.ssh_keys
  server_type = var.small_server_type
  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }
  network {
    network_id = hcloud_network.main.id
    ip         = ""
  }
}

resource "random_pet" "postgresql" {
  count = local.postgresql_count
}

resource "hcloud_server" "postgresql" {
  depends_on = [
    null_resource.deployment_info,
    hcloud_network_subnet.main
  ]
  count       = local.postgresql_count
  location    = var.location
  name        = "postgresql-${random_pet.postgresql[count.index].id}"
  image       = "ubuntu-22.04"
  ssh_keys    = local.ssh_keys
  server_type = var.small_server_type
  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }
  network {
    network_id = hcloud_network.main.id
    ip         = ""
  }
}

resource "random_pet" "rabbitmq" {
  count = local.rabbitmq_count
}

resource "hcloud_server" "rabbitmq" {
  depends_on = [
    null_resource.deployment_info,
    hcloud_network_subnet.main
  ]
  count       = local.rabbitmq_count
  location    = var.location
  name        = "rabbitmq-${random_pet.rabbitmq[count.index].id}"
  image       = "ubuntu-22.04"
  ssh_keys    = local.ssh_keys
  server_type = var.small_server_type
  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }
  network {
    network_id = hcloud_network.main.id
    ip         = ""
  }
}
