# a security group for access to the private traffic between kubernetes nodes. should be added to all kubernetes nodes.
resource "aws_security_group" "talk_to_S3" {
  name        = "talk_to_S3"
  description = "hosts that are allowed to talk to S3."
  vpc_id      = var.vpc_id

  # S3
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