resource "aws_route53_record" "a" {
  for_each = toset(length(var.ips) > 0 ? var.subdomains : [])

  zone_id = data.aws_route53_zone.rz.zone_id
  name    = join(".", concat([each.value], local.name_suffix))
  type    = "A"
  ttl     = var.ttl
  records = var.ips
}


resource "aws_route53_record" "cname" {
  for_each = toset(length(var.cnames) > 0 ? var.subdomains : [])

  zone_id = data.aws_route53_zone.rz.zone_id
  name    = join(".", concat([each.value], local.name_suffix))
  type    = "CNAME"
  ttl     = var.ttl
  records = var.cnames
}

resource "aws_route53_record" "spf" {
  count = var.create_spf_record ? 1 : 0

  zone_id = data.aws_route53_zone.rz.zone_id
  name    = join(".", local.name_suffix)
  type    = "TXT"
  ttl     = "60"
  records = [ for ip in var.ips : "v=spf1 ip4:${ ip } -all" ]
}
