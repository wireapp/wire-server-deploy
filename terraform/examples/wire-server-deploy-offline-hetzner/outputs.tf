output "ssh_private_key" {
  sensitive = true
  value     = tls_private_key.admin.private_key_pem
}

output "selected_server_types" {
  description = "Server types selected after checking availability"
  value = {
    small_server_type  = local.small_server_type
    medium_server_type = local.medium_server_type
  }
}

output "selected_location" {
  description = "Location selected after checking availability"
  value       = local.selected_location
}

output "resource_fallback_info" {
  description = "Information about resource fallback selections"
  value = {
    requested_locations = local.preferred_locations
    available_locations = local.available_location_names
    selected_location   = local.selected_location

    requested_small_types = local.preferred_server_types.small
    available_small_types = local.available_small_server_types
    selected_small_type   = local.small_server_type

    requested_medium_types = local.preferred_server_types.medium
    available_medium_types = local.available_medium_server_types
    selected_medium_type   = local.medium_server_type
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
        ansible_user            = "root"
        private_interface       = "enp7s0"
        adminhost_ip            = tolist(hcloud_server.adminhost.network)[0].ip
      }
    }
    adminhost = {
      hosts = {
        "adminhost" = {
          ansible_host = hcloud_server.adminhost.ipv4_address
        }
      }
      vars = {
        ansible_ssh_common_args = "-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null -o ControlMaster=auto -o ControlPersist=60s -o BatchMode=yes -o ConnectionAttempts=10 -o ServerAliveInterval=60 -o ServerAliveCountMax=3"
      }
    }
    private = {
      children = {
        adminhost_local = {}
        assethost       = {}
        "kube-node"     = {}
        cassandra       = {}
        elasticsearch   = {}
        minio           = {}
        postgresql      = {}
        rmq-cluster     = {}
      }
      vars = {
        ansible_ssh_common_args = "-o ProxyCommand=\"ssh -i ssh_private_key -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null -W %h:%p -q root@${hcloud_server.adminhost.ipv4_address}\" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null -o ControlMaster=auto -o ControlPersist=60s -o BatchMode=yes -o ConnectionAttempts=10 -o ServerAliveInterval=60 -o ServerAliveCountMax=3"
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
    etcd = {
      children = { "kube-master" = {} }
    }
    kube-master = {
      children = { "kube-node" = {} }
    }
    kube-node = {
      hosts = {
        for index, server in hcloud_server.kubenode : server.name => {
          ansible_host     = tolist(hcloud_server.kubenode[index].network)[0].ip
          ip               = tolist(hcloud_server.kubenode[index].network)[0].ip
          etcd_member_name = server.name
        }
      }
    }
    k8s-cluster = {
      children = {
        "kube-node"   = {}
        "kube-master" = {}
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
    cassandra = {
      hosts = {
        for index, server in hcloud_server.cassandra : server.name => {
          ansible_host = tolist(hcloud_server.cassandra[index].network)[0].ip
        }
      }
      vars = {
        cassandra_network_interface = "enp7s0"
      }
    }
    cassandra_seed = {
      hosts = { (hcloud_server.cassandra[0].name) = {} }
    }
    elasticsearch = {
      hosts = {
        for index, server in hcloud_server.elasticsearch : server.name => {
          ansible_host = tolist(hcloud_server.elasticsearch[index].network)[0].ip
        }
      }
      vars = {
        elasticsearch_network_interface = "enp7s0"
      }
    }
    elasticsearch_master = {
      children = { "elasticsearch" = {} }
    }
    minio = {
      hosts = {
        for index, server in hcloud_server.minio : server.name => {
          ansible_host = tolist(hcloud_server.minio[index].network)[0].ip
        }
      }
      vars = {
        minio_network_interface = "enp7s0"
      }
    }
    postgresql = {
      hosts = {
        for index, server in hcloud_server.postgresql : "postgresql${index + 1}" => {
          ansible_host = tolist(hcloud_server.postgresql[index].network)[0].ip
        }
      }
      vars = {
        wire_dbname                  = "wire-server"
        postgresql_network_interface = "enp7s0"
      }
    }
    postgresql_rw = {
      hosts = { "postgresql1" = {} }
    }
    postgresql_ro = {
      hosts = { "postgresql2" = {},
      "postgresql3" = {} }
    }
    rmq-cluster = {
      hosts = {
        # host names here must match each node's actual hostname
        for index, server in hcloud_server.rabbitmq : server.name => {
          ansible_host = tolist(hcloud_server.rabbitmq[index].network)[0].ip
        }
      }
      vars = {
        # host name here must match each node's actual hostname
        rabbitmq_cluster_master    = hcloud_server.rabbitmq[0].name
        rabbitmq_network_interface = "enp7s0"
      }
    }
  }
}
