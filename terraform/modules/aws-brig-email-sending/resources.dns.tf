resource "aws_route53_record" "ses_domain_verification_record" {
  zone_id = var.zone_id
  name    = "_amazonses.${var.domain}"
  type    = "TXT"
  ttl     = "600"
  records = [aws_ses_domain_identity.brig.verification_token]
}

# Apparently, the amount of tokens that AWS is handing out, amounts for the count of 3,
# which is why one might find examples that hard-code this number by setting `count = 3`
# example: https://www.terraform.io/docs/providers/aws/r/ses_domain_dkim.html
# docs: https://docs.aws.amazon.com/ses/latest/DeveloperGuide/send-email-authentication-dkim-easy-setup-domain.html
#
resource "aws_route53_record" "ses_domain_dkim_record" {
  count   = length(aws_ses_domain_dkim.brig.dkim_tokens)
  zone_id = var.zone_id
  name    = "${element(aws_ses_domain_dkim.brig.dkim_tokens, count.index)}._domainkey.${var.domain}"
  type    = "CNAME"
  ttl     = "600"
  records = ["${element(aws_ses_domain_dkim.brig.dkim_tokens, count.index)}.dkim.amazonses.com"]
}

# NOTE: in order to configure MAIL FROM
# docs: https://www.terraform.io/docs/providers/aws/r/ses_domain_mail_from.html
#
resource "aws_route53_record" "ses_domain_mail_from_mx" {
  zone_id = var.zone_id
  name    = aws_ses_domain_mail_from.brig.mail_from_domain
  type    = "MX"
  ttl     = "600"
  records = ["10 feedback-smtp.${data.aws_region.current.name}.amazonses.com"]
}

resource "aws_route53_record" "ses_domain_mail_from_spf" {
  zone_id = var.zone_id
  name    = aws_ses_domain_mail_from.brig.mail_from_domain
  type    = "TXT"
  ttl     = "600"
  records = ["v=spf1 include:amazonses.com -all"]
}
