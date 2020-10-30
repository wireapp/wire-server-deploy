# Configure the DigitalOcean Provider
provider "digitalocean" {
}
data "digitalocean_ssh_key" "tmate" {
  name = "tmate"
}

# k8s-cluster = kube-node + kube-master
# etcd j
# kube-node, kube-master, etcd, all the same
resource "digitalocean_droplet" "kube_node" {
  count  = 3
  name   = "node${count.index}"
  image  = "ubuntu-18-04-x64"
  region = "ams3"
  size   = "s-1vcpu-2gb"
  ssh_keys = [data.digitalocean_ssh_key.tmate.id]
}

locals {
  kube_node    = digitalocean_droplet.kube_node
  kube_master  = digitalocean_droplet.kube_node
  etcd         = digitalocean_droplet.kube_node
  all_droplets = distinct(concat(local.kube_node, local.kube_master, local.etcd))
}


# Output format as documented here:
# https://docs.ansible.com/ansible/latest/dev_guide/developing_inventory.html#developing-inventory-scripts
output "ansible-inventory" {
  value = {
    _meta = {
      hostvars = {
        for droplet in local.all_droplets : droplet.name => {
          ansible_host = droplet.ipv4_address
          ip = droplet.ipv4_address_private
          etcd_member_name = droplet.name # this is redundant for things outside etcd group; but doesn't hurt
        }
      }
    }
    kube-master = [ for droplet in local.kube_master : droplet.name ]
    kube-node = [ for droplet in local.kube_node : droplet.name ]
    etcd = [ for droplet in local.etcd : droplet.name ]
    k8s-cluster = {
      children = ["kube-master", "kube-node"]
    }

  }
}

