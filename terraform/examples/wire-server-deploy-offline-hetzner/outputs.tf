output "ssh_private_key" {
  sensitive = true
  value = tls_private_key.admin.private_key_pem
}
output "adminhost" {
  sensitive = true
  value = hcloud_server.adminhost.ipv4_address
}
# output format that a static inventory file expects
output "static-inventory" {
  sensitive = true
  value = {
    adminhost = {
      hosts = {
        "adminhost" = {
          ansible_host = hcloud_server.adminhost.ipv4_address
          ansible_user = "root"
        }
      }
    }
    assethost = {
      hosts = {
        "assethost" = {
          ansible_host = tolist(hcloud_server.assethost.network)[0].ip
          ansible_user = "root"
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
          ansible_user     = "root"
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
        docker_dns_servers_strict: false
      }
    }
    cassandra = {
      hosts = {
        for index, server in hcloud_server.cassandra : server.name => {
          ansible_host = tolist(hcloud_server.cassandra[index].network)[0].ip
          ansible_user = "root"
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
          ansible_user = "root"
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
          ansible_user = "root"
        }
      }
      vars = {
        minio_network_interface = "enp7s0"
      }
    }
    postgresql = {
      hosts = {
        for index, server in hcloud_server.postgresql :  "postgresql${index + 1}" => {
          ansible_host = tolist(hcloud_server.postgresql[index].network)[0].ip
          ansible_user = "root"
          wire_dbname = "wire-server"
          wire_user = "wire-server"
          wire_pass = "verysecurepassword"
        }
      }
      vars = {
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
  }
}
