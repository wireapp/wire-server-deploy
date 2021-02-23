module "kubernetes-dns-records" {
  for_each = toset(var.root_domain != null && length(var.sub_domains) > 0 ? [var.environment] : [])

  source = "../modules/aws-dns-records"

  zone_fqdn = var.root_domain
  domain = var.environment
  subdomains = var.sub_domains
  ips = module.hetzner_k8s_cluster[var.environment].ips
  # NOTE: this list could have been generated similar to ./kubernetes.inventory.tf, but
  #       Terraform thinks differently. While building up the dependency tree, it appears
  #       that it is not able to see indirect dependencies, e.g. local.cluster_machines.  #
  #       It fails at modules/aws-dns-records/resources.route53.tf resource aws_route53_record.spf.count
  #       with:
  #
  #         The "count" value depends on resource attributes that cannot be determined until apply
  #
  #       So, in order to work around this, a second output for public node IPs is being introduced.
  spf_record_ips = module.hetzner_k8s_cluster[var.environment].node_ips
}
