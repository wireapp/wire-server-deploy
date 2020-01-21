# Example terraform script to create virtual machines on the hetzner cloud provider 
# and an ansible-compatible inventory file
terraform {
  required_version = ">= 0.12.1"

  # Recommended: configure a backend to share terraform state
  # See terraform documentation
}

# Configure the Hetzner Cloud Provider
provider "hcloud" {
  # You must have a HCLOUD_TOKEN environment variable set!
}

resource "hcloud_ssh_key" "default" {
  name       = "myssh-key"
  public_key = file("secrets/myssh-key")
}

resource "hcloud_server" "node" {
  count       = 1
  name        = "kubenode0${count.index + 1}"
  image       = "ubuntu-18.04"
  server_type = "cx51"
  ssh_keys    = [
    hcloud_ssh_key.default.name
  ]

  # Nuremberg (for choices see `hcloud datacenter list`)
  location = "nbg1"

  labels = {
    member = "etcd0${count.index + 1}"
  }
}

resource "local_file" "inventory" {
  filename    = "${path.module}/hosts.ini"
  content     = templatefile( "${path.module}/inventory.tpl", {
    connection_strings_node          = "${join("\n", formatlist("%s ansible_host=%s etcd_member_name=%s", hcloud_server.node.*.name, hcloud_server.node.*.ipv4_address, hcloud_server.node.*.labels.member ))}"
    list_master                      = "${join("\n",hcloud_server.node.*.name)}"
    list_etcd                        = "${join("\n",hcloud_server.node.*.name)}"
    list_node                        = "${join("\n",hcloud_server.node.*.name)}"
  })
}
