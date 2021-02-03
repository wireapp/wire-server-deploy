module "kubernetes-dns-records" {
  for_each = toset(var.root_domain != null && length(var.sub_domains) > 0 ? [var.environment] : [])

  source = "../modules/aws-dns-records"

  zone_fqdn = var.root_domain
  domain = var.environment
  subdomains = var.sub_domains
  ips = [ for node in local.kubernetes_nodes: node.ipaddress ]
  create_spf_record = var.create_spf_record
}
