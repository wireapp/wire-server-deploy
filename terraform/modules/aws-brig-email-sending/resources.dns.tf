resource "aws_route53_record" "domain_amazonses_dkim_record" {
  count   = "${var.zone_id != "" ? length(var.dkim_records) : 0}"
  zone_id = "${var.zone_id}"
  name    = "${element(keys(var.dkim_records), count.index)}"
  type    = "CNAME"
  ttl     = "${var.dkim_ttl}"
  records = ["${element(values(var.dkim_records), count.index)}"]
}

resource "aws_route53_record" "domain_amazonses_verification_record" {
  count   = "${var.zone_id != "" ? 1 : 0}"
  zone_id = "${var.zone_id}"
  name    = "_amazonses.${var.domain}"
  type    = "TXT"
  ttl     = "${var.ses_ttl}"
  records = ["${aws_ses_domain_identity.domain.verification_token}"]
}