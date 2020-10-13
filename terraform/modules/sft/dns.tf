data "aws_route53_zone" "sft_zone" {
  name = var.root_domain
}

resource "aws_route53_record" "sft_a" {
  for_each = setunion(var.server_groups.blue.server_names, var.server_groups.green.server_names)

  zone_id = data.aws_route53_zone.sft_zone.zone_id
  name    = "sft${each.value}.sft.${var.environment}"
  type    = "A"
  ttl     = var.a_record_ttl
  records = [hcloud_server.sft[each.key].ipv4_address]
}

resource "aws_route53_record" "metrics_srv" {
  zone_id = data.aws_route53_zone.sft_zone.zone_id
  name = "_sft-metrics._tcp.${var.environment}"
  type = "SRV"
  ttl = var.metrics_srv_record_ttl
  records = [for a_record in aws_route53_record.sft_a : "0 10 8443 ${a_record.fqdn}"]
}
