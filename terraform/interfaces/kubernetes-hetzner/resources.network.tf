# TODO: feed into the kubernetes module

resource "hcloud_network" "nw" {
  count = var.network_id != null ? 1 : 0

  name = "k8s-${ var.name }"

  ip_range = "192.168.0.0/16"
}


resource "hcloud_network_subnet" "sn" {
  count = var.network_id != null && var.subnet_id != null ? 1 : 0

  network_id = hcloud_network.nw.id

  ip_range   = "192.168.1.0/24"

  # NOTE: No other sensible values available at this time
  # DOCS: https://docs.hetzner.cloud/#subnets
  type = "cloud"
  network_zone = "eu-central"
}
