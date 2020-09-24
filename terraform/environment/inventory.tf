# Generates an inventory file to be used by ansible. Ideally, we would generate
# this outside terraform using outputs, but it is not possible to use 'terraform
# output' when the init directory is different from the root code directory.
# Terraform Issue: https://github.com/hashicorp/terraform/issues/17300
locals {
  kubernetes_hosts = {for node in module.hetzner_kubernetes[0].nodes : node.hostname => {} }
}

resource "local_file" "inventory" {
  filename = var.inventory_file
  content = jsonencode({
    "sft_servers" = {
      "hosts" = { for instance in module.sft[0].sft.instances :  instance.hostname => {
        "ansible_host" = instance.ipaddress
        "ansible_ssh_user" = "root"
        # NOTE: Maybe this is not required for ansible 2.9
        "ansible_python_interpreter" = "/usr/bin/python3"
        "sft_fqdn" = instance.fqdn

        "announcer_zone_domain" = var.root_domain
        "announcer_aws_key_id" = module.sft[0].sft.aws_key_id
        "announcer_aws_access_key" = module.sft[0].sft.aws_access_key
        "announcer_aws_region" = module.sft[0].sft.aws_region
        "announcer_srv_records" = {
          "sft" = {
            "name" = "_sft._tcp.${var.environment}"
            "target" = instance.fqdn
          }
        }
      }}
    }
    "kube-master"  = {"hosts" = local.kubernetes_hosts}
    "kube-node" = {"hosts" = local.kubernetes_hosts}
    "etcd" = {"hosts" = local.kubernetes_hosts}
    "k8s-cluster" = {
      "hosts" = {for node in module.hetzner_kubernetes[0].nodes :
        node.hostname => {
          "ansible_host" = node.ipaddress
          "etcd_member_name" = node.etcd_member_name
        }
      }
      "vars" = {
        "ansible_ssh_user" = "root"
        # NOTE: Maybe this is not required for ansible 2.9
        "ansible_python_interpreter" = "/usr/bin/python3"

        "helm_enabled" = true
        "kubeconfig_localhost" = true
        "bootstrap_os" = "ubuntu"
        "docker_dns_servers_strict" = false
      }
    }
  })
}
