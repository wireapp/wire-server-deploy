locals {
  cluster_machines = length(module.hetzner_k8s_cluster) > 0 ? lookup(module.hetzner_k8s_cluster[var.environment], "machines", []) : []
}

locals {
  k8s_cluster_inventory = {
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
      vars = {
        ansible_ssh_user = "root"
        # NOTE: Maybe this is not required for ansible 2.9
        ansible_python_interpreter = "/usr/bin/python3"

        helm_enabled = true
        kubeconfig_localhost = true
        bootstrap_os = "ubuntu"
        docker_dns_servers_strict = false
      }
    }
  }
}
