resource "hcloud_network" "nw" {
  name = "k8s-${ var.cluster_name }"

  ip_range = "192.168.0.0/16"
}


resource "hcloud_network_subnet" "sn" {
  network_id = hcloud_network.nw.id

  ip_range   = "192.168.1.0/24"

  # NOTE: No other sensible values available at this time
  # DOCS: https://docs.hetzner.cloud/#subnets
  type = "cloud"
  network_zone = "eu-central"
}