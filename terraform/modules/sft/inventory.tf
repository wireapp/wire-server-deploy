# TODO: It is absurd that srv-announcer requires this. All route53 resources are
# scoped globally, figure out if we really need to do this.
data "aws_region" "current" {}

resource "local_file" "inventory_hosts" {
  filename    = var.inventory_file
  file_permission = "0755"

  content     = templatefile(
    "${path.module}/templates/inventory.yml.tpl",
    {
      env: var.environment
      awsKeyID = aws_iam_access_key.srv-announcer.id
      awsAccessKey = aws_iam_access_key.srv-announcer.secret
      awsRegion = data.aws_region.current.name
      zoneDomain = var.root_domain
      instances = [ for server_name in var.server_names :
        {
          hostname = hcloud_server.sft[server_name].name
          ipaddress = hcloud_server.sft[server_name].ipv4_address
          fqdn = aws_route53_record.sft_a[server_name].fqdn
        }
      ]
    }
    )
}
