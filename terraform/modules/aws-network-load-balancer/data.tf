data "aws_vpc" "this" {
  filter {
    name   = "tag:Environment"
    values = [var.environment]
  }
}
