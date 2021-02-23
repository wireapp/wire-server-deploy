locals {
  sft_instances_blue = flatten(module.sft[*].sft.instances_blue)
  sft_instances_green = flatten(module.sft[*].sft.instances_green)
}

locals {
  sft_inventory = {
    sft_servers = {
      hosts = { for instance in concat(local.sft_instances_blue, local.sft_instances_green): instance.hostname => {
        ansible_host = instance.ipaddress
        sft_fqdn = instance.fqdn
        srv_announcer_record_target = instance.fqdn
        srv_announcer_zone_domain = var.root_domain
        srv_announcer_aws_key_id = module.sft[0].sft.aws_key_id
        srv_announcer_aws_access_key = module.sft[0].sft.aws_access_key
        srv_announcer_aws_region = module.sft[0].sft.aws_region
        srv_announcer_record_name = "_sft._tcp.${var.environment}"
        ansible_python_interpreter = "/usr/bin/python3"
        ansible_ssh_user = "root"
      }}
    }
    sft_servers_blue = {
      hosts = { for instance in local.sft_instances_blue : instance.hostname => {} }
    }
    sft_servers_green = {
      hosts = { for instance in local.sft_instances_green : instance.hostname => {} }
    }
  }
}
