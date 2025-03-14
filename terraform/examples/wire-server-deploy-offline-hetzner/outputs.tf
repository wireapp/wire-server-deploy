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

    assethost = {
      hosts = {
        "assethost" = {
          ansible_host = hcloud_server_network.assethost.ip
          ansible_user = "root"
        }
      }
    }
    adminhost = {
      hosts = {
        "adminhost" = {
          ansible_host = hcloud_server.adminhost.ipv4_address
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
          ansible_host     = hcloud_server_network.kubenode[index].ip
          ip               = hcloud_server_network.kubenode[index].ip
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
          ansible_host = hcloud_server_network.cassandra[index].ip
          ansible_user = "root"
        }
      }
      vars = {
        cassandra_network_interface = "eth0"
      }
    }
    cassandra_seed = {
      hosts = { (hcloud_server.cassandra[0].name) = {} }
    }
    elasticsearch = {
      hosts = {
        for index, server in hcloud_server.elasticsearch : server.name => {
          ansible_host = hcloud_server_network.elasticsearch[index].ip
          ansible_user = "root"
        }
      }
      vars = {
        elasticsearch_network_interface = "eth0"
      }
    }
    elasticsearch_master = {
      children = { "elasticsearch" = {} }
    }
    minio = {
      hosts = {
        for index, server in hcloud_server.minio : server.name => {
          ansible_host = hcloud_server_network.minio[index].ip
          ansible_user = "root"
        }
      }
      vars = {
        minio_network_interface = "eth0"
      }
    }
  }
}
