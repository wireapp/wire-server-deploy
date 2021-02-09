locals {
  kubernetes_nodes = flatten(module.hetzner_kubernetes[*].nodes)
  kubernetes_hosts = {for node in local.kubernetes_nodes : node.hostname => {}}
}

locals {
  k8s_cluster_inventory = {
    kube-master  = { hosts = local.kubernetes_hosts }
    kube-node = { hosts = local.kubernetes_hosts }
    etcd = { hosts = local.kubernetes_hosts }
    minio = { hosts = local.kubernetes_hosts }
    k8s-cluster = {
      children = {
        kube-master = {}
        kube-node = {}
      }
      hosts = {for node in local.kubernetes_nodes :
        node.hostname => {
          ansible_host = node.ipaddress
          etcd_member_name = node.etcd_member_name
        }
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
