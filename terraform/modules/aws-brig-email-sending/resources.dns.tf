resource "aws_route53_record" "domain_amazonses_verification_record" {
  zone_id = var.zone_id
  name    = "_amazonses.${var.email_domain}"
  type    = "TXT"
  ttl     = "600"
  records = [ aws_ses_domain_identity.brig.verification_token ]
}

resource "aws_route53_record" "domain_amazonses_dkim_record" {
  count   = 3
  zone_id = var.zone_id
  name    = "${element(aws_ses_domain_dkim.brig.dkim_tokens, count.index)}._domainkey.${var.email_domain}"
  type    = "CNAME"
  ttl     = "600"
  records = [ "${element(aws_ses_domain_dkim.brig.dkim_tokens, count.index)}.dkim.amazonses.com" ]
}
