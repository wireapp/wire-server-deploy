locals {
  servers_private_ip = { for _, snw in hcloud_server_network.snw : snw.server_id => snw.ip }
  servers_volume_device_path = { for _, vol in hcloud_volume.volumes : vol.server_id => vol.linux_device }
}


output "machines" {
  value = [ for _, machine in hcloud_server.machines :
    merge(
      {
        hostname = machine.name
        private_ipv4 = local.servers_private_ip[machine.id]
        public_ipv4 = machine.ipv4_address
        component_classes = [
          for label_name, _ in machine.labels :
            split("/", label_name)[1]
              if replace(label_name, "component-class.${local.LABEL_PREFIX}", "") != label_name
        ]
      },
      contains( keys(machine.labels), "etcd_member_name" )
        ? { etcd_member_name = machine.labels.etcd_member_name }
        : {},
      contains( keys(local.servers_volume_device_path), machine.id )
        ? { volume = { device_path = local.servers_volume_device_path[machine.id] } }
        : {},
    )
  ]
}
