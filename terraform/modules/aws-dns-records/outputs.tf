output "fqdns" {
  value = concat(
    [for record in aws_route53_record.a : record.fqdn],
    [for record in aws_route53_record.cname : record.fqdn]
  )
}
