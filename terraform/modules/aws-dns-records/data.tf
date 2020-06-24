data "aws_route53_zone" "rz" {
  name = "${var.zone_fqdn}."
}
