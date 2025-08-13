locals {
  rfc1918_cidr        = "10.0.0.0/8"
  kubenode_count      = 3
  minio_count         = 2
  elasticsearch_count = 2
  cassandra_count     = 3
  postgresql_count    = 3
  ssh_keys            = [hcloud_ssh_key.adminhost.name]
}


resource "random_pet" "main" {
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
  location    = "nbg1"
  name        = "adminhost-${random_pet.adminhost.id}"
  image       = "ubuntu-22.04"
  ssh_keys    = local.ssh_keys
  server_type = "cpx41"
  network {
  network_id = hcloud_network.main.id
  ip         = ""
  }
  depends_on = [
    hcloud_network_subnet.main
  ]
}

# The server hosting all the bootstrap assets
resource "random_pet" "assethost" {
}

resource "hcloud_server" "assethost" {
  location    = "nbg1"
  name        = "assethost-${random_pet.assethost.id}"
  image       = "ubuntu-22.04"
  ssh_keys    = local.ssh_keys
  server_type = "cpx41"
  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }
  network {
  network_id = hcloud_network.main.id
  ip         = ""
  }
  depends_on = [
    hcloud_network_subnet.main
  ]
}

resource "random_pet" "kubenode" {
  count = local.kubenode_count
}

resource "hcloud_server" "kubenode" {
  count       = local.kubenode_count
  location    = "nbg1"
  name        = "kubenode-${random_pet.kubenode[count.index].id}"
  image       = "ubuntu-22.04"
  ssh_keys    = local.ssh_keys
  server_type = "cpx41"
  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }
  network {
  network_id = hcloud_network.main.id
  ip         = ""
  }
  depends_on = [
    hcloud_network_subnet.main
  ]
}

resource "random_pet" "cassandra" {
  count = local.cassandra_count
}

resource "hcloud_server" "cassandra" {
  count       = local.cassandra_count
  location    = "nbg1"
  name        = "cassandra-${random_pet.cassandra[count.index].id}"
  image       = "ubuntu-22.04"
  ssh_keys    = local.ssh_keys
  server_type = "cx22"
  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }
  network {
  network_id = hcloud_network.main.id
  ip         = ""
  }
  depends_on = [
    hcloud_network_subnet.main
  ]
}

resource "random_pet" "elasticsearch" {
  count = local.elasticsearch_count
}

resource "hcloud_server" "elasticsearch" {
  count       = local.elasticsearch_count
  location    = "nbg1"
  name        = "elasticsearch-${random_pet.elasticsearch[count.index].id}"
  image       = "ubuntu-22.04"
  ssh_keys    = local.ssh_keys
  server_type = "cx22"
  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }
  network {
  network_id = hcloud_network.main.id
  ip         = ""
  }
  depends_on = [
    hcloud_network_subnet.main
  ]
}

resource "random_pet" "minio" {
  count = local.minio_count
}

resource "hcloud_server" "minio" {
  count       = local.minio_count
  location    = "nbg1"
  name        = "minio-${random_pet.minio[count.index].id}"
  image       = "ubuntu-22.04"
  ssh_keys    = local.ssh_keys
  server_type = "cx22"
  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }
  network {
  network_id = hcloud_network.main.id
  ip         = ""
  }
  depends_on = [
    hcloud_network_subnet.main
  ]
}

resource "random_pet" "postgresql" {
  count = local.postgresql_count
}

resource "hcloud_server" "postgresql" {
  count       = local.postgresql_count
  location    = "nbg1"
  name        = "postgresql-${random_pet.postgresql[count.index].id}"
  image       = "ubuntu-22.04"
  ssh_keys    = local.ssh_keys
  server_type = "cx22"
  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }
  network {
  network_id = hcloud_network.main.id
  ip         = ""
  }
  depends_on = [
    hcloud_network_subnet.main
  ]
}
