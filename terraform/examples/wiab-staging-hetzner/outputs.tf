output "ssh_private_key" {
  sensitive = true
  value     = tls_private_key.admin.private_key_pem
}

output "selected_server_types" {
  description = "Server types selected for the current deployment attempt"
  value = {
    small_server_type  = var.small_server_type
    medium_server_type = var.medium_server_type
  }
}

output "selected_location" {
  description = "Location selected for the current deployment attempt"
  value       = var.location
}

output "resource_fallback_info" {
  description = "Information about the requested deployment combination and its availability"
  value = {
    requested_location  = var.location
    available_locations = local.available_location_names
    selected_location   = var.location

    requested_small_type = var.small_server_type
    selected_small_type  = var.small_server_type

    requested_medium_type = var.medium_server_type
    selected_medium_type  = var.medium_server_type

    available_server_types = local.available_server_type_names
  }
}

output "adminhost" {
  sensitive = true
  value     = hcloud_server.adminhost.ipv4_address
}
# output format that a static inventory file expects
output "static-inventory" {
  sensitive = true
  value = {
    all = {
      vars = {
        adminhost_ip      = tolist(hcloud_server.adminhost.network)[0].ip
        ansible_user      = "root"
        private_interface = "enp7s0"
      }
    }
    adminhost = {
      hosts = {
        "adminhost" = {
          ansible_host = hcloud_server.adminhost.ipv4_address
        }
      }
      vars = {
        ansible_ssh_common_args = "-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null -o ControlMaster=auto -o ControlPersist=60s -o BatchMode=yes -o ConnectionAttempts=10 -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o ConnectTimeout=10"
      }
    }
    private = {
      children = {
        assethost       = {}
        datanode        = {}
        "kube-node"     = {}
        adminhost_local = {}
      }
      vars = {
        ansible_ssh_common_args = "-o ProxyCommand=\"ssh -i ssh_private_key -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null -W %h:%p -q root@${hcloud_server.adminhost.ipv4_address}\" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null -o ControlMaster=auto -o ControlPersist=60s -o BatchMode=yes -o ConnectionAttempts=10 -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o ConnectTimeout=10"
      }
    }
    adminhost_local = {
      hosts = {
        "adminhost_local" = {
          ansible_host = tolist(hcloud_server.adminhost.network)[0].ip
        }
      }
    }
    assethost = {
      hosts = {
        "assethost" = {
          ansible_host = tolist(hcloud_server.assethost.network)[0].ip
        }
      }
    }
    kube-node = {
      hosts = {
        for index, server in hcloud_server.kubenode : server.name => {
          ansible_host = tolist(hcloud_server.kubenode[index].network)[0].ip
          ip           = tolist(hcloud_server.kubenode[index].network)[0].ip
        }
      }
      # NOTE: Necessary for the Hetzner Cloud until Calico v3.17 arrives in Kubespray
      # Hetzner private networks have an MTU of 1450 instead of 1500
      vars = {
        calico_mtu      = 1450
        calico_veth_mtu = 1430
        # NOTE: relax handling a list with more than 3 items; required on Hetzner
        docker_dns_servers_strict = false
        upstream_dns_servers      = [tolist(hcloud_server.adminhost.network)[0].ip]
      }
    }
    datanode = {
      hosts = {
        for index, server in hcloud_server.datanode : server.name => {
          ansible_host = tolist(hcloud_server.datanode[index].network)[0].ip
        }
      }
      vars = {
        datanode_network_interface = "enp7s0"
      }
    }
  }
}
