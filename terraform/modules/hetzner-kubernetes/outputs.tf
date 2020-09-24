output "nodes" {
  value = [ for node in hcloud_server.node :
      {
        hostname = node.name
        ipaddress = node.ipv4_address
        etcd_member_name = node.labels.member
      }
    ]
}
