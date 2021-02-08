# FUTUREWORK: Attach a volume for etcd state, so we can recreate this machine
# when we need to.
resource "hcloud_server" "node" {
  count       = var.node_count
  name        = "${ var.environment }-kubenode${ format("%02d", count.index + 1 )}"
  image       = var.image
  server_type = var.server_type
  ssh_keys    = var.ssh_keys
  location    = var.location

  labels = {
    # FUTUREWORK: This label name is very undecriptive and it should be renamed
    # to "etcd_member_name". This is kept as it is because legacy environments
    # have it.
    member = "etcd${ format("%02d", count.index + 1 )}"
  }
}
