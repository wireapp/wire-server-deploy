# TODO: refactor this when creating a second environment. re: names being unique for security groups.

# A security group for ssh from the outside world. should only be applied to our bastion hosts.
resource "aws_security_group" "world_ssh_in" {
  name        = "world_ssh_in"
  description = "ssh in from the outside world"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "world_ssh_in"
  }
}

# A security group for access to the outside world over http and https. should only be applied to our bastion host.
resource "aws_security_group" "world_web_out" {
  name        = "world_web_out"
  description = "http/https to the outside world"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "world_web_out"
  }
}

# A security group for making ssh connections inside the VPC. should be added to the admin and bastion hosts only.
resource "aws_security_group" "ssh_from" {
  name        = "ssh_from"
  description = "hosts that are allowed to ssh into other hosts"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["172.17.0.0/20"]
  }

  tags = {
    Name = "ssh_from"
  }
}

# A security group for recieving ssh connections inside the VPC. should be added to every host.
resource "aws_security_group" "has_ssh" {
  name        = "has_ssh"
  description = "hosts that should be reachable via SSH."
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = ["${aws_security_group.ssh_from.id}"]
  }

  tags = {
    Name = "has_ssh"
  }
}

# A security group for getting resources from the assethost. should be added to all nodes except the bastion host.
resource "aws_security_group" "talk_to_assets" {
  name        = "talk_to_assets"
  description = "hosts that are allowed to request assets from the asset host"
  vpc_id      = var.vpc_id

  # DNS
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["172.17.0.0/20"]
  }

  # DNS
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["172.17.0.0/20"]
  }

  # Time
  egress {
    from_port   = 123
    to_port     = 123
    protocol    = "udp"
    cidr_blocks = ["172.17.0.0/20"]
  }

  # HTTP
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["172.17.0.0/20"]
  }

  # HTTPS
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["172.17.0.0/20"]
  }

  tags = {
    Name = "talk_to_assets"
  }
}

# A security group for serving assets inside the VPC. should be added to the assethost only.
resource "aws_security_group" "has_assets" {
  name        = "has_assets"
  description = "hosts that serve ASSETS."
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 53
    to_port         = 53
    protocol        = "tcp"
    security_groups = ["${aws_security_group.talk_to_assets.id}"]
  }

  ingress {
    from_port       = 53
    to_port         = 53
    protocol        = "udp"
    security_groups = ["${aws_security_group.talk_to_assets.id}"]
  }

  # Time
  ingress {
    from_port       = 123
    to_port         = 123
    protocol        = "udp"
    security_groups = ["${aws_security_group.talk_to_assets.id}"]
  }

  # HTTP
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = ["${aws_security_group.talk_to_assets.id}"]
  }

  # HTTPS
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = ["${aws_security_group.talk_to_assets.id}"]
  }

  tags = {
    Name = "has_assets"
  }
}

# A security group for access to kubernetes nodes. should be added to the admin host only.
resource "aws_security_group" "talk_to_k8s" {
  name        = "talk_to_k8s"
  description = "hosts that are allowed to speak to kubernetes."
  vpc_id      = var.vpc_id

  egress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["172.17.0.0/20"]
  }

  tags = {
    Name = "talk_to_k8s"
  }
}

# A security group for kubernetes nodes. should be added to them only.
resource "aws_security_group" "k8s_node" {
  name        = "k8s_node"
  description = "hosts that have kubernetes."
  vpc_id      = var.vpc_id

  # incoming from the admin node (kubectl)
  ingress {
    from_port       = 6443
    to_port         = 6443
    protocol        = "tcp"
    security_groups = ["${aws_security_group.talk_to_k8s.id}"]
  }

  # incoming from NLB
  ingress {
    from_port       = 31772
    to_port         = 31773
    protocol        = "tcp"
    # NOTE: NLBs dont allow security groups to be be set on them, which is why
    # we go with the CIDR for now, which is hard-coded and evil and needs fixing
    cidr_blocks = ["172.17.0.0/20"]
  }

  # FIXME: tighten this up.
  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = ["${aws_security_group.k8s_private.id}"]
  }

  # FIXME: tighten this up. need UDP for flannel.
  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "udp"
    security_groups = ["${aws_security_group.k8s_private.id}"]
  }

  tags = {
    Name = "k8s_node"
  }
}

# a security group for access to the private traffic between kubernetes nodes. should be added to all kubernetes nodes.
resource "aws_security_group" "k8s_private" {
  name        = "k8s_private"
  description = "hosts that are allowed to the private ports of the kubernetes nodes."
  vpc_id      = var.vpc_id

  # FIXME: tighten this up.
  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["172.17.0.0/20"]
  }

  # FIXME: tighten this up. need UDP for flannel.
  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = ["172.17.0.0/20"]
  }

  tags = {
    Name = "k8s_private"
  }
}


# A security group for access to the stateful services. should be added to all k8s nodes, and the admin node.
resource "aws_security_group" "talk_to_stateful" {
  name        = "talk_to_stateful"
  description = "hosts that are allowed to speak to the stateful services."
  vpc_id      = var.vpc_id

  # cassandra
  egress {
    from_port   = 9042
    to_port     = 9042
    protocol    = "tcp"
    cidr_blocks = ["172.17.0.0/20"]
  }

  # elasticsearch
  egress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = ["172.17.0.0/20"]
  }

  # minio
  egress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["172.17.0.0/20"]
  }

  # minio
  egress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = ["172.17.0.0/20"]
  }

  tags = {
    Name = "talk_to_stateful"
  }
}

# A security group for access to the private traffic between stateful services. should be added to all ansible nodes.
resource "aws_security_group" "stateful_private" {
  name        = "stateful_private"
  description = "hosts that are allowed to speak to the private ports of the stateful services."
  vpc_id      = var.vpc_id

  # cassandra non-TLS
  egress {
    from_port   = 7000
    to_port     = 7000
    protocol    = "tcp"
    cidr_blocks = ["172.17.0.0/20"]
  }

  # cassandra TLS
  egress {
    from_port   = 9160
    to_port     = 9160
    protocol    = "tcp"
    cidr_blocks = ["172.17.0.0/20"]
  }

  # ElasticSearch
  egress {
    from_port   = 9300
    to_port     = 9300
    protocol    = "tcp"
    cidr_blocks = ["172.17.0.0/20"]
  }

  # minio
  egress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["172.17.0.0/20"]
  }

  # minio
  egress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = ["172.17.0.0/20"]
  }

  tags = {
    Name = "stateful_private"
  }
}

# A security group for stateful service nodes. should be added to them only.
resource "aws_security_group" "stateful_node" {
  name        = "stateful_node"
  description = "hosts that host stateful services."
  vpc_id      = var.vpc_id

  # incoming cassandra clients
  ingress {
    from_port       = 9042
    to_port         = 9042
    protocol        = "tcp"
    security_groups = ["${aws_security_group.talk_to_stateful.id}"]
  }

  # incoming elasticsearch clients.
  ingress {
    from_port       = 9200
    to_port         = 9200
    protocol        = "tcp"
    security_groups = ["${aws_security_group.talk_to_stateful.id}"]
  }

  # incoming minio clients.
  ingress {
    from_port       = 9000
    to_port         = 9000
    protocol        = "tcp"
    security_groups = ["${aws_security_group.talk_to_stateful.id}"]
  }

  # incoming minio clients.
  ingress {
    from_port       = 9092
    to_port         = 9092
    protocol        = "tcp"
    security_groups = ["${aws_security_group.talk_to_stateful.id}"]
  }

  # other cassandra nodes (non-TLS)
  ingress {
    from_port       = 7000
    to_port         = 7000
    protocol        = "tcp"
    security_groups = ["${aws_security_group.stateful_private.id}"]
  }

  # other cassandra nodes (TLS)
  ingress {
    from_port       = 9160
    to_port         = 9160
    protocol        = "tcp"
    security_groups = ["${aws_security_group.stateful_private.id}"]
  }

  # other elasticsearch nodes
  ingress {
    from_port       = 9300
    to_port         = 9300
    protocol        = "tcp"
    security_groups = ["${aws_security_group.stateful_private.id}"]
  }

  # other minio nodes
  ingress {
    from_port       = 9000
    to_port         = 9000
    protocol        = "tcp"
    security_groups = ["${aws_security_group.stateful_private.id}"]
  }

  # other minio nodes
  ingress {
    from_port       = 9092
    to_port         = 9092
    protocol        = "tcp"
    security_groups = ["${aws_security_group.stateful_private.id}"]
  }

  tags = {
    Name = "stateful_node"
  }
}
