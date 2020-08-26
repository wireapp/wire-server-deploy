resource "aws_security_group" "talk_to_S3" {
  name        = "talk_to_S3"
  description = "hosts that are allowed to talk to S3."
  vpc_id      = var.vpc_id

  egress {
    description = ""
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = aws_vpc_endpoint.s3.cidr_blocks
  }

  tags = {
    Name = "talk_to_S3"
  }
}
