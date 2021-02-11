locals {
  cluster_machines = try(module.hetzner_k8s_cluster[var.environment].machines, [])
}

locals {
  k8s_cluster_inventory = length(local.cluster_machines) > 0 ? {
    kube-master = { hosts = { for m in local.cluster_machines : m.hostname => {} if contains(m.component_classes, "controlplane" ) } }
    kube-node = { hosts = { for m in local.cluster_machines : m.hostname => {} if contains(m.component_classes, "node" ) } }
    etcd = { hosts = { for m in local.cluster_machines : m.hostname => {} if contains(keys(m), "etcd_member_name" ) } }
    minio = { hosts = { for m in local.cluster_machines : m.hostname => {} if contains(m.component_classes, "minio" ) } }
    k8s-cluster = {
      children = {
        kube-master = {}
        kube-node = {}
      }
      hosts = {for m in local.cluster_machines :
        m.hostname => merge(
          {
            ansible_host = m.public_ipv4
            ip = m.private_ipv4
          },
          contains(keys(m), "etcd_member_name" ) ? { etcd_member_name = m.etcd_member_name } : {}
        )
      }
      vars = merge(
        {
          ansible_ssh_user = "root"
          # NOTE: Maybe this is not required for ansible 2.9
          ansible_python_interpreter = "/usr/bin/python3"

          helm_enabled = true
          kubeconfig_localhost = true
          bootstrap_os = "ubuntu"
          docker_dns_servers_strict = false
        },
        local.load_balancer_is_used ? { apiserver_loadbalancer_domain_name = module.hetzner_k8s_cluster[var.environment].ips[0] } : {}
      )
    }
  } : tomap({})
}
