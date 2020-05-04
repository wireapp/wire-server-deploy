resource "aws_route53_record" "ses_domain_verification_record" {
  count = local.emailing_enabled

  zone_id = var.zone_id
  name    = "_amazonses.${var.domain}"
  type    = "TXT"
  ttl     = "600"
  records = [ aws_ses_domain_identity.brig[0].verification_token ]
}

# Apparently, the amount of tokens that AWS is handing out, amounts for the count of 3,
# which is why one might find examples that hard-code this number by setting `count = 3`
# example: https://www.terraform.io/docs/providers/aws/r/ses_domain_dkim.html
# docs: https://docs.aws.amazon.com/ses/latest/DeveloperGuide/send-email-authentication-dkim-easy-setup-domain.html
#
resource "aws_route53_record" "ses_domain_dkim_record" {
  # FUTUREWORK: try replacing `3` with `length( aws_ses_domain_dkim.brig[0].dkim_tokens )`
  count   = var.enable_email_sending ? 3 : 0

  zone_id = var.zone_id
  name    = "${element(aws_ses_domain_dkim.brig[0].dkim_tokens, count.index)}._domainkey.${var.domain}"
  type    = "CNAME"
  ttl     = "600"
  records = [ "${element(aws_ses_domain_dkim.brig[0].dkim_tokens, count.index)}.dkim.amazonses.com" ]
}

resource "aws_route53_record" "ses_domain_spf" {
  count = local.emailing_enabled

  zone_id = var.zone_id
  name    = aws_ses_domain_identity.brig[0].domain
  type    = "TXT"
  ttl     = "600"
  records = [ "v=spf1 include:amazonses.com -all" ]
}

# indicate compliance with SPF or DKIM
# docs: https://dmarc.org/wiki/FAQ
#       https://docs.aws.amazon.com/ses/latest/DeveloperGuide/send-email-authentication-dmarc.html
#
resource "aws_route53_record" "ses_domain_dmarc" {
  count = local.emailing_enabled

  zone_id = var.zone_id
  name    = "_dmarc.${aws_ses_domain_identity.brig[0].domain}"
  type    = "TXT"
  ttl     = "600"
  records = [ "v=DMARC1; p=quarantine; pct=25; rua=mailto:dmarcreports@${aws_ses_domain_identity.brig[0].domain}" ]
}

# NOTE: in order to configure MAIL FROM
# docs: https://www.terraform.io/docs/providers/aws/r/ses_domain_mail_from.html
#
resource "aws_route53_record" "ses_domain_mail_from_mx" {
  count = local.emailing_enabled

  zone_id = var.zone_id
  name    = aws_ses_domain_mail_from.brig[0].mail_from_domain
  type    = "MX"
  ttl     = "600"
  records = [ "10 feedback-smtp.${data.aws_region.current.name}.amazonses.com" ]
}

resource "aws_route53_record" "ses_domain_mail_from_spf" {
  count = local.emailing_enabled

  zone_id = var.zone_id
  name    = aws_ses_domain_mail_from.brig[0].mail_from_domain
  type    = "TXT"
  ttl     = "600"
  records = [ "v=spf1 include:amazonses.com -all" ]
}
