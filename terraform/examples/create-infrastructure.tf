# Example terraform script to create virtual machines on the hetzner cloud provider 
# and an ansible-compatible inventory file
terraform {
  required_version = "~> 1.1"

  # Recommended: configure a backend to share terraform state
  # See terraform documentation
}

# Configure the Hetzner Cloud Provider
provider "hcloud" {
  # You must have a HCLOUD_TOKEN environment variable set!
}

resource "hcloud_ssh_key" "default" {
  name       = "myssh-key"
  public_key = "${file("secrets/myssh-key")}"
}

resource "hcloud_server" "node" {
  count       = 3
  name        = "node${count.index}"
  image       = "ubuntu-22.04"
  server_type = "cx42"
  ssh_keys    = ["hetznerssh-key"]
  # Nuremberg (for choices see `hcloud datacenter list`)
  location = "nbg1"
}

resource "hcloud_server" "etcd" {
  count       = 3
  name        = "etcd${count.index}"
  image       = "ubuntu-22.04"
  server_type = "cx42"
  ssh_keys    = ["hetznerssh-key"]

  # Nuremberg (for choices see `hcloud datacenter list`)
  location = "nbg1"
}

resource "hcloud_server" "redis" {
  count       = 0
  name        = "redis${count.index}"
  image       = "ubuntu-22.04"
  server_type = "cx22"
  ssh_keys    = ["hetznerssh-key"]

  # Nuremberg (for choices see `hcloud datacenter list`)
  location = "nbg1"
}

resource "hcloud_server" "restund" {
  count       = 2
  name        = "restund${count.index}"
  image       = "ubuntu-22.04"
  server_type = "cx22"
  ssh_keys    = ["hetznerssh-key"]

  # Nuremberg (for choices see `hcloud datacenter list`)
  location = "nbg1"
}

resource "hcloud_server" "minio" {
  count       = 3
  name        = "minio${count.index}"
  image       = "ubuntu-22.04"
  server_type = "cx22"
  ssh_keys    = ["hetznerssh-key"]

  # Nuremberg (for choices see `hcloud datacenter list`)
  location = "nbg1"
}

resource "hcloud_server" "cassandra" {
  count       = 3
  name        = "cassandra${count.index}"
  image       = "ubuntu-22.04"
  server_type = "cx22"
  ssh_keys    = ["hetznerssh-key"]

  # Nuremberg (for choices see `hcloud datacenter list`)
  location = "nbg1"
}

resource "hcloud_server" "elasticsearch" {
  count       = 3
  name        = "elasticsearch${count.index}"
  image       = "ubuntu-22.04"
  server_type = "cx22"
  ssh_keys    = ["hetznerssh-key"]

  # Nuremberg (for choices see `hcloud datacenter list`)
  location = "nbg1"
}

resource "null_resource" "vpnkube" {
  count = "${length(hcloud_server.node)}"

  triggers = {
    ip     = "10.10.1.${10 + count.index}"
  }
}

resource "null_resource" "vpnetcd" {
  count = "${length(hcloud_server.etcd)}"

  triggers = {
    ip     = "10.10.1.${60 + count.index}"
    member = "etcd_${count.index}"
  }
}

resource "null_resource" "vpnminio" {
  count = "${length(hcloud_server.minio)}"

  triggers = {
    ip = "10.10.1.${20 + count.index}"
  }
}

resource "null_resource" "vpncass" {
  count = "${length(hcloud_server.cassandra)}"

  triggers = {
    ip = "10.10.1.${30 + count.index}"
  }
}

resource "null_resource" "vpnes" {
  count = "${length(hcloud_server.elasticsearch)}"

  triggers = {
    ip = "10.10.1.${40 + count.index}"
  }
}

resource "null_resource" "vpnredis" {
  count = "${length(hcloud_server.redis)}"

  triggers = {
    ip = "10.10.1.${50 + count.index}"
  }
}

data "template_file" "inventory" {
  template = "${file("inventory.tpl")}"

  vars = {
    connection_strings_node          = "${join("\n", formatlist("%s ansible_host=%s vpn_ip=%s ip=%s", hcloud_server.node.*.name, hcloud_server.node.*.ipv4_address, null_resource.vpnkube.*.triggers.ip, null_resource.vpnkube.*.triggers.ip))}"
    connection_strings_etcd          = "${join("\n", formatlist("%s ansible_host=%s vpn_ip=%s ip=%s etcd_member_name=%s", hcloud_server.etcd.*.name, hcloud_server.etcd.*.ipv4_address, null_resource.vpnetcd.*.triggers.ip, null_resource.vpnetcd.*.triggers.ip, null_resource.vpnetcd.*.triggers.member))}"
    connection_strings_cassandra     = "${join("\n", formatlist("%s ansible_host=%s vpn_ip=%s", hcloud_server.cassandra.*.name, hcloud_server.cassandra.*.ipv4_address, null_resource.vpncass.*.triggers.ip))}"
    connection_strings_elasticsearch = "${join("\n", formatlist("%s ansible_host=%s vpn_ip=%s", hcloud_server.elasticsearch.*.name, hcloud_server.elasticsearch.*.ipv4_address, null_resource.vpnes.*.triggers.ip))}"
    connection_strings_minio         = "${join("\n", formatlist("%s ansible_host=%s vpn_ip=%s", hcloud_server.minio.*.name, hcloud_server.minio.*.ipv4_address, null_resource.vpnminio.*.triggers.ip))}"
    connection_strings_redis         = "${join("\n", formatlist("%s ansible_host=%s vpn_ip=%s", hcloud_server.redis.*.name, hcloud_server.redis.*.ipv4_address, null_resource.vpnredis.*.triggers.ip))}"
    connection_strings_restund       = "${join("\n", formatlist("%s ansible_host=%s", hcloud_server.restund.*.name, hcloud_server.restund.*.ipv4_address))}"
    list_master                      = "${join("\n",hcloud_server.node.*.name)}"
    list_etcd                        = "${join("\n",hcloud_server.etcd.*.name)}"
    list_node                        = "${join("\n",hcloud_server.node.*.name)}"
    list_cassandra                   = "${join("\n",hcloud_server.cassandra.*.name)}"
    list_elasticsearch               = "${join("\n",hcloud_server.elasticsearch.*.name)}"
    list_minio                       = "${join("\n",hcloud_server.minio.*.name)}"
    list_redis                       = "${join("\n",hcloud_server.redis.*.name)}"
    list_restund                     = "${join("\n",hcloud_server.restund.*.name)}"
  }
}

resource "null_resource" "inventories" {
  provisioner "local-exec" {
    command = "echo '${data.template_file.inventory.rendered}' > hosts.ini"
  }

  triggers = {
    template = "${data.template_file.inventory.rendered}"
  }
}
