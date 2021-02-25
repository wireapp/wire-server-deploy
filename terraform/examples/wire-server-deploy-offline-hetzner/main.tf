# In offline; we just set up 3 kubenodes; and they are all control-plane nodes
resource "hcloud_ssh_key" "github_actions" {
  name       = "github-actions"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPt32jJeOVLUKTn06ySR7cWrXuSGzgCSmtsfJFRiAonP github-actions@wireapp"
}

locals {
  rfc1918_cidr        = "10.0.0.0/8"
  kubenode_count      = 3
  minio_count         = 2
  elasticsearch_count = 2
  cassandra_count     = 3
  restund_count       = 2
  ssh_keys            = [hcloud_ssh_key.adminhost.name, hcloud_ssh_key.github_actions.name]

  disable_network_cfg = <<-EOF
  #cloud-config
  runcmd:
    - iptables -A OUTPUT -o eth0 -j DROP
  EOF
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

resource "tls_private_key" "adminhost" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "hcloud_ssh_key" "adminhost" {
  name       = "adminhost-${random_pet.adminhost.id}"
  public_key = tls_private_key.adminhost.public_key_openssh
}

# Connected to all other servers. Simulates the admin's "laptop"
resource "hcloud_server" "adminhost" {
  location    = "nbg1"
  name        = "adminhost-${random_pet.adminhost.id}"
  image       = "ubuntu-18.04"
  ssh_keys    = local.ssh_keys
  server_type = "cx41"
  user_data   = <<-EOF
  #cloud-config
  apt:
    sources:
      docker.list:
        source: deb [arch=amd64] https://download.docker.com/linux/ubuntu $RELEASE stable
        keyid: 9DC858229FC7DD38854AE2D88D81803C0EBFCD88
  packages:
    - docker-ce
    - docker-ce-cli
  write_files:
    - content: "${base64encode(tls_private_key.adminhost.private_key_pem)}"
      encoding: b64
      path: /root/.ssh/id_ecdsa
      permissions: '0600'
  EOF
}

resource "hcloud_server_network" "adminhost" {
  server_id = hcloud_server.adminhost.id
  subnet_id = hcloud_network_subnet.main.id
}

resource "random_pet" "assethost" {
}

# The server hosting all the bootstrap assets
resource "hcloud_server" "assethost" {
  location    = "nbg1"
  name        = "assethost-${random_pet.assethost.id}"
  image       = "ubuntu-18.04"
  ssh_keys    = local.ssh_keys
  server_type = "cx41"
  user_data   = local.disable_network_cfg
}

resource "hcloud_server_network" "assethost" {
  server_id = hcloud_server.assethost.id
  subnet_id = hcloud_network_subnet.main.id
}


resource "random_pet" "restund" {
  count = local.restund_count
}

resource "hcloud_server" "restund" {
  count       = local.restund_count
  location    = "nbg1"
  name        = "restund-${random_pet.restund[count.index].id}"
  image       = "ubuntu-18.04"
  ssh_keys    = local.ssh_keys
  server_type = "cx11"
  user_data   = local.disable_network_cfg
}

resource "hcloud_server_network" "restund" {
  count     = local.restund_count
  server_id = hcloud_server.restund[count.index].id
  subnet_id = hcloud_network_subnet.main.id
}


resource "random_pet" "kubenode" {
  count = local.kubenode_count
}

resource "hcloud_server" "kubenode" {
  count       = local.kubenode_count
  location    = "nbg1"
  name        = "kubenode-${random_pet.kubenode[count.index].id}"
  image       = "ubuntu-18.04"
  ssh_keys    = local.ssh_keys
  server_type = "cx41"
  user_data   = local.disable_network_cfg
}

resource "hcloud_server_network" "kubenode" {
  count     = local.kubenode_count
  server_id = hcloud_server.kubenode[count.index].id
  subnet_id = hcloud_network_subnet.main.id
}


resource "random_pet" "cassandra" {
  count = local.cassandra_count
}

resource "hcloud_server" "cassandra" {
  count       = local.cassandra_count
  location    = "nbg1"
  name        = "cassandra-${random_pet.cassandra[count.index].id}"
  image       = "ubuntu-18.04"
  ssh_keys    = local.ssh_keys
  server_type = "cx11"
  user_data   = local.disable_network_cfg
}

resource "hcloud_server_network" "cassandra" {
  count     = local.cassandra_count
  server_id = hcloud_server.cassandra[count.index].id
  subnet_id = hcloud_network_subnet.main.id
}


resource "random_pet" "elasticsearch" {
  count = local.elasticsearch_count
}

resource "hcloud_server" "elasticsearch" {
  count       = local.elasticsearch_count
  location    = "nbg1"
  name        = "elasticsearch-${random_pet.elasticsearch[count.index].id}"
  image       = "ubuntu-18.04"
  ssh_keys    = local.ssh_keys
  server_type = "cx11"
  user_data   = local.disable_network_cfg
}

resource "hcloud_server_network" "elasticsearch" {
  count     = local.elasticsearch_count
  server_id = hcloud_server.elasticsearch[count.index].id
  subnet_id = hcloud_network_subnet.main.id
}


resource "random_pet" "minio" {
  count = local.minio_count
}

resource "hcloud_server" "minio" {
  count       = local.minio_count
  location    = "nbg1"
  name        = "minio-${random_pet.minio[count.index].id}"
  image       = "ubuntu-18.04"
  ssh_keys    = local.ssh_keys
  server_type = "cx11"
  user_data   = local.disable_network_cfg
}

resource "hcloud_server_network" "minio" {
  count     = local.minio_count
  server_id = hcloud_server.minio[count.index].id
  subnet_id = hcloud_network_subnet.main.id
}
