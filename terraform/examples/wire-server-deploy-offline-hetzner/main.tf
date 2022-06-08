locals {
  rfc1918_cidr        = "10.0.0.0/8"
  kubenode_count      = 3
  minio_count         = 2
  elasticsearch_count = 2
  cassandra_count     = 3
  restund_count       = 2
  ssh_keys            = [hcloud_ssh_key.adminhost.name]

  # TODO: IPv6
  disable_network_cfg = <<-EOF
  #cloud-config
  runcmd:

    # Allow DNS
    - iptables -A OUTPUT -o eth0 -p udp --dport 53  -j ACCEPT
    - ip6tables -A OUTPUT -o eth0 -p udp --dport 53  -j ACCEPT

    # Allow NTP
    - iptables -A OUTPUT -o eth0 -p udp --dport 123 -j ACCEPT
    - ip6tables -A OUTPUT -o eth0 -p udp --dport 123 -j ACCEPT

    # Drop all other traffic
    - iptables -A OUTPUT -o eth0 -j DROP
    - ip6tables -A OUTPUT -o eth0 -j DROP

  EOF
}


resource "random_pet" "main" {
}

# TODO: these need to be unique across all runs, too
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


resource "tls_private_key" "admin" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "hcloud_ssh_key" "adminhost" {
  name       = "${random_pet.main.id}-adminhost"
  public_key = tls_private_key.admin.public_key_openssh
}

# Connected to all other servers. Simulates the admin's "laptop"
resource "hcloud_server" "adminhost" {
  location    = "nbg1"
  name        = "${random_pet.main.id}-adminhost"
  image       = "ubuntu-18.04"
  ssh_keys    = local.ssh_keys
  server_type = "cx31"
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
  users:
    - name: admin
      groups:
        - sudo
      shell: /bin/bash
      ssh_authorized_keys:
        - "${tls_private_key.admin.public_key_openssh}"
  EOF
}

resource "hcloud_server_network" "adminhost" {
  server_id = hcloud_server.adminhost.id
  subnet_id = hcloud_network_subnet.main.id
}

# The server hosting all the bootstrap assets
resource "hcloud_server" "assethost" {
  location    = "nbg1"
  name        = "${random_pet.main.id}-assethost"
  image       = "ubuntu-18.04"
  ssh_keys    = local.ssh_keys
  server_type = "cx31"
  user_data   = local.disable_network_cfg
}

resource "hcloud_server_network" "assethost" {
  server_id = hcloud_server.assethost.id
  subnet_id = hcloud_network_subnet.main.id
}

resource "hcloud_server" "restund" {
  count       = local.restund_count
  location    = "nbg1"
  name        = "${random_pet.main.id}-restund-${count.index}"
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

resource "hcloud_server" "kubenode" {
  count       = local.kubenode_count
  location    = "nbg1"
  name        = "${random_pet.main.id}-kubenode-${count.index}"
  image       = "ubuntu-18.04"
  ssh_keys    = local.ssh_keys
  server_type = "cx31"
  user_data   = local.disable_network_cfg
}

resource "hcloud_server_network" "kubenode" {
  count     = local.kubenode_count
  server_id = hcloud_server.kubenode[count.index].id
  subnet_id = hcloud_network_subnet.main.id
}

resource "hcloud_server" "cassandra" {
  count       = local.cassandra_count
  location    = "nbg1"
  name        = "${random_pet.main.id}-cassandra-${count.index}"
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

resource "hcloud_server" "elasticsearch" {
  count       = local.elasticsearch_count
  location    = "nbg1"
  name        = "${random_pet.main.id}-elasticsearch-${count.index}"
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

resource "hcloud_server" "minio" {
  count       = local.minio_count
  location    = "nbg1"
  name        = "${random_pet.main.id}-minio-${count.index}"
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
