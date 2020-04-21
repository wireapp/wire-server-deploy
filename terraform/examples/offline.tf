# This file is meant to define the 'offline' environment, which lives in the 'crash' trust zone.
# See also https://github.com/zinfra/backend-issues/wiki/trust-zone-environments (TODO: move that page over to either the zinfra/backend-wiki's wiki, or to zinfra/backend-wiki's repository)

# What is an Offline VPC?
# The only host reachable from the outside is a bastion host. It has internet access, and provides SSH services. It can access all of the other hosts in the VPC via SSH only.

# To deploy this file, you will need a user with the policies "AmazonEC2FullAccess", "IAMFullAccess", "AmazonS3FullAccess", and "AmazonDynamoDBFullAccess".
# FUTUREWORK: drill down on the above.

terraform {
  required_version = ">= 0.12.0"

  backend "s3" {
    encrypt = true
    region  = "eu-central-1"

    # TODO: create IAM policy which only allows access to this bucket under
    # envrionments/crash and to the -crash dynamodb table
    bucket = "z-terraform-remote-state"

    key = "environments/offline/bootstrap"

    dynamodb_table = "z-terraform-state-lock-dynamo-lock-environment-offline"
  }
}

# In AWS, (eu-central-1)
provider "aws" {
  region = "eu-central-1"
}

# Used for the in-VPC EC2 endpoint.
data "aws_security_group" "default" {
  name   = "default"
  vpc_id = module.vpc.vpc_id
}

module "vpc" {
  source = "github.com/terraform-aws-modules/terraform-aws-vpc"

  name = "offline"

  cidr = "172.17.0.0/20"

  azs             = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  private_subnets = ["172.17.0.0/22", "172.17.4.0/22", "172.17.8.0/22"]
  public_subnets  = ["172.17.12.0/24", "172.17.13.0/24", "172.17.14.0/24"]

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_dhcp_options      = true
  dhcp_options_domain_name = "offline.zinfra.io"
#  dhcp_options_domain_name_servers = 
  
  # In case we run terraform from within the environment.
  # VPC endpoint for DynamoDB
  enable_dynamodb_endpoint = true

  # In case we run terraform from within the environment.
  # VPC Endpoint for EC2
  enable_ec2_endpoint              = true
  ec2_endpoint_private_dns_enabled = true
  ec2_endpoint_security_group_ids  = [data.aws_security_group.default.id]

  enable_nat_gateway = true
  one_nat_gateway_per_az = false
# Use this only in productionish environments.
#  one_nat_gateway_per_az = true

  tags = {
    Owner       = "Backend Team"
    Environment = "Offline"
    TrustZone   = "Crash"
  }
  vpc_tags = {
    Owner       = "Backend Team"
    Name        = "vpc-offline"
    TrustZone   = "Crash"
  }
}

# A SSH key, used during golden image creation. destroyed at the end of the process.
resource "aws_key_pair" "crash-nonprod-deployer-julia" {
  key_name   = "crash-nonprod-deployer-julia"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDANkhpvNjsWoYRt5ji82+K3QNXLNdr4V+1LRzI0PXUiIxGLw80LSEXuCQVD3S2OWE5BuBzZtTTD4gy+/Mic5U7/2tePtMJYLkTV8vwvD9nx1YQPUSiIiUcCVX6gpw/YmyACvso+2M3ageEHJzuad+ZNsuYah0g5Y1NFABbRnPHl2zIfyCl0efu1mz5ucY5Kxe8oHEH/gUEuhUSgpZpANjExdu44Gujry4dfypJ3F4nZzJXMWtEmiTnEZCJ24wfdBUnBqk4If2yLczFFRECtT6t4AQU6/AyJ5OYsX5AWcKr67qmBG8pJrwHJF0M9tBJhDkFZb+6XrUW3p3Oj8XNs2ubfcJofJaeP3ZzLz7LADXf8fvRcSruD9k7STGORptB4MFkF9vI7Xp/3fN71kVQ6zw1Pwdifnfkd03SOjj2JxOsSuXqXsSECFqFo7XF2m6xCB5fywdmHoOGzXy17FGGxpTunoe6C7zcHu5tVCTy6LZ6eFAzYK/h8lRnhvSiHXxXoX0= demo@boxtop"
}

# Finding AMIs:
# https://cloud-images.ubuntu.com/locator/ec2/

data "aws_ami" "ubuntu18LTS-ARM64" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-arm64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
  }

data "aws_ami" "ubuntu18LTS-AMD64" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
  }

# Finding Instance types:
# https://www.ec2instances.info/

# point an elastic IP to our bastion host.
resource "aws_eip" "bastion-offline" {
  vpc                       = true
#network_interface         = "${aws_network_interface.bastion-crash-in.id}"
  instance = "${aws_instance.bastion-offline.id}"
}

# A security group for ssh from the outside world. should only be applied to our bastion hosts.
resource "aws_security_group" "world_ssh_in" {
  name        = "world_ssh_in"
  description = "ssh in from the outside world"
  vpc_id      = module.vpc.vpc_id

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
  vpc_id      = module.vpc.vpc_id

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
  vpc_id      = module.vpc.vpc_id

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
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
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
  vpc_id      = module.vpc.vpc_id

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
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    security_groups = ["${aws_security_group.talk_to_assets.id}"]
  }

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    security_groups = ["${aws_security_group.talk_to_assets.id}"]
  }

  # Time
  ingress {
    from_port   = 123
    to_port     = 123
    protocol    = "udp"
    security_groups = ["${aws_security_group.talk_to_assets.id}"]
    }

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = ["${aws_security_group.talk_to_assets.id}"]
    }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
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
  vpc_id      = module.vpc.vpc_id

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
  vpc_id      = module.vpc.vpc_id

  # incoming from the admin node (kubectl)
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    security_groups = ["${aws_security_group.talk_to_k8s.id}"]
  }

  # FIXME: tighten this up.
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    security_groups = ["${aws_security_group.k8s_private.id}"]
  }

  # FIXME: tighten this up. need UDP for flannel.
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
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
  vpc_id      = module.vpc.vpc_id

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


# A security group for access to the ephemeral services. should be added to all k8s nodes, and the admin node.
resource "aws_security_group" "talk_to_ephemeral" {
  name        = "talk_to_ephemeral"
  description = "hosts that are allowed to speak to the ephemeral services."
  vpc_id      = module.vpc.vpc_id

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
    Name = "talk_to_ephemeral"
  }
}

# A security group for access to the private traffic between ephemeral services. should be added to all ansible nodes.
resource "aws_security_group" "ephemeral_private" {
  name        = "ephemeral_private"
  description = "hosts that are allowed to speak to the private ports of the ephemeral services."
  vpc_id      = module.vpc.vpc_id

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
    Name = "ephemeral_private"
  }
}

# A security group for ephemeral service nodes. should be added to them only.
resource "aws_security_group" "ephemeral_node" {
  name        = "ephemeral_node"
  description = "hosts that host ephemeral services."
  vpc_id      = module.vpc.vpc_id

  # incoming cassandra clients
  ingress {
    from_port   = 9042
    to_port     = 9042
    protocol    = "tcp"
    security_groups = ["${aws_security_group.talk_to_ephemeral.id}"]
  }

  # incoming elasticsearch clients.
  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    security_groups = ["${aws_security_group.talk_to_ephemeral.id}"]
  }

  # incoming minio clients.
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    security_groups = ["${aws_security_group.talk_to_ephemeral.id}"]
  }

  # incoming minio clients.
  ingress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    security_groups = ["${aws_security_group.talk_to_ephemeral.id}"]
  }

  # other cassandra nodes (non-TLS)
  ingress {
    from_port   = 7000
    to_port     = 7000
    protocol    = "tcp"
    security_groups = ["${aws_security_group.ephemeral_private.id}"]
  }

  # other cassandra nodes (TLS)
  ingress {
    from_port   = 9160
    to_port     = 9160
    protocol    = "tcp"
    security_groups = ["${aws_security_group.ephemeral_private.id}"]
  }

  # other elasticsearch nodes
  ingress {
    from_port   = 9300
    to_port     = 9300
    protocol    = "tcp"
    security_groups = ["${aws_security_group.ephemeral_private.id}"]
  }

  # other minio nodes
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    security_groups = ["${aws_security_group.ephemeral_private.id}"]
  }

  # other minio nodes
  ingress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    security_groups = ["${aws_security_group.ephemeral_private.id}"]
  }

  tags = {
    Name = "ephemeral_node"
  }
}

# our bastion host
resource "aws_instance" "bastion-offline" {
  ami           = "${data.aws_ami.ubuntu18LTS-ARM64.id}"
  instance_type = "a1.medium"
  subnet_id     = "${module.vpc.public_subnets[0]}"
  key_name      = "${aws_key_pair.crash-nonprod-deployer-julia.key_name}"
  root_block_device {
      volume_size = 20
  }
  tags = {
      Name = "bastion-offline",
      Environment = "offline",
      Role = "bastion"
  }
  vpc_security_group_ids = [
    "${aws_security_group.world_ssh_in.id}",
    "${aws_security_group.world_web_out.id}",
    "${aws_security_group.ssh_from.id}"
    ]
}

# our admin host
resource "aws_instance" "admin-offline" {
  ami           = "${data.aws_ami.ubuntu18LTS-AMD64.id}"
  instance_type = "m3.medium"
  subnet_id     = "${module.vpc.private_subnets[0]}"
  key_name      = "${aws_key_pair.crash-nonprod-deployer-julia.key_name}"
  tags = {
      Name = "admin-offline",
      Environment = "offline",
      Role = "admin"
  }
  vpc_security_group_ids = [
    "${aws_security_group.ssh_from.id}",
    "${aws_security_group.talk_to_assets.id}",
    "${aws_security_group.talk_to_ephemeral.id}",
    "${aws_security_group.talk_to_k8s.id}",
    "${aws_security_group.has_ssh.id}"
    ]
}

## our vpn endpoint
#resource "aws_instance" "vpn-offline" {
#  ami           = "${data.aws_ami.ubuntu18LTS-AMD64.id}"
#  instance_type = "m3.medium"
#  subnet_id     = "${module.vpc.private_subnets[0]}"
#  key_name      = "${aws_key_pair.crash-nonprod-deployer-julia.key_name}"
#  tags = {
#      Name = "vpn-offline",
#      Environment = "offline",
#      Role = "vpn"
#  }
#  vpc_security_group_ids = [
#    "${aws_security_group.talk_to_assets.id}",
#    "${aws_security_group.has_ssh.id}"
#    ]
#}

# our assethost host
resource "aws_instance" "assethost-offline" {
  ami           = "${data.aws_ami.ubuntu18LTS-AMD64.id}"
  instance_type = "m3.medium"
  subnet_id     = "${module.vpc.private_subnets[0]}"
  key_name      = "${aws_key_pair.crash-nonprod-deployer-julia.key_name}"
  root_block_device {
      volume_size = 40
  }
  tags = {
      Name = "assethost-offline",
      Environment = "offline",
      Role = "terminator"
  }
  vpc_security_group_ids = [
    "${aws_security_group.has_ssh.id}",
    "${aws_security_group.has_assets.id}",
    ]
}

# our kubernetes endpoints
resource "aws_instance" "kubenode1-offline" {
  ami           = "${data.aws_ami.ubuntu18LTS-AMD64.id}"
  instance_type = "m5.xlarge"
  subnet_id     = "${module.vpc.private_subnets[0]}"
  key_name      = "${aws_key_pair.crash-nonprod-deployer-julia.key_name}"
  tags = {
      Name = "kubenode1-offline",
      Environment = "offline",
      Role = "kubenode"
  }
  vpc_security_group_ids = [
    "${aws_security_group.talk_to_assets.id}",
    "${aws_security_group.has_ssh.id}",
    "${aws_security_group.k8s_private.id}",
    "${aws_security_group.talk_to_ephemeral.id}",
    "${aws_security_group.k8s_node.id}"
    ]
}

resource "aws_instance" "kubenode2-offline" {
  ami           = "${data.aws_ami.ubuntu18LTS-AMD64.id}"
  instance_type = "m5.xlarge"
  subnet_id     = "${module.vpc.private_subnets[0]}"
  key_name      = "${aws_key_pair.crash-nonprod-deployer-julia.key_name}"
  tags = {
      Name = "kubenode2-offline",
      Environment = "offline",
      Role = "kubenode"
  }
  vpc_security_group_ids = [
    "${aws_security_group.talk_to_assets.id}",
    "${aws_security_group.has_ssh.id}",
    "${aws_security_group.k8s_private.id}",
    "${aws_security_group.talk_to_ephemeral.id}",
    "${aws_security_group.k8s_node.id}"
    ]
}

# our kubernetes endpoints
resource "aws_instance" "kubenode3-offline" {
  ami           = "${data.aws_ami.ubuntu18LTS-AMD64.id}"
  instance_type = "m5.xlarge"
  subnet_id     = "${module.vpc.private_subnets[0]}"
  key_name      = "${aws_key_pair.crash-nonprod-deployer-julia.key_name}"
  tags = {
      Name = "kubenode3-offline",
      Environment = "offline",
      Role = "kubenode"
  }
  vpc_security_group_ids = [
    "${aws_security_group.talk_to_assets.id}",
    "${aws_security_group.has_ssh.id}",
    "${aws_security_group.k8s_private.id}",
    "${aws_security_group.talk_to_ephemeral.id}",
    "${aws_security_group.k8s_node.id}"
    ]
}

# our ephemeral service endpoints
resource "aws_instance" "ansnode1-offline" {
  ami           = "${data.aws_ami.ubuntu18LTS-AMD64.id}"
  instance_type = "m5.large"
  subnet_id     = "${module.vpc.private_subnets[0]}"
  key_name      = "${aws_key_pair.crash-nonprod-deployer-julia.key_name}"
  tags = {
      Name = "ansnode1-offline",
      Environment = "offline",
      Role = "ansnode"
  }
  vpc_security_group_ids = [
    "${aws_security_group.talk_to_assets.id}",
    "${aws_security_group.ephemeral_node.id}",
    "${aws_security_group.ephemeral_private.id}",
    "${aws_security_group.has_ssh.id}"
    ]
}

resource "aws_instance" "ansnode2-offline" {
  ami           = "${data.aws_ami.ubuntu18LTS-AMD64.id}"
  instance_type = "m5.large"
  subnet_id     = "${module.vpc.private_subnets[0]}"
  key_name      = "${aws_key_pair.crash-nonprod-deployer-julia.key_name}"
  tags = {
      Name = "ansnode2-offline",
      Environment = "offline",
      Role = "ansnode"
  }
  vpc_security_group_ids = [
    "${aws_security_group.talk_to_assets.id}",
    "${aws_security_group.ephemeral_node.id}",
    "${aws_security_group.ephemeral_private.id}",
    "${aws_security_group.has_ssh.id}"
    ]
}

resource "aws_instance" "ansnode3-offline" {
  ami           = "${data.aws_ami.ubuntu18LTS-AMD64.id}"
  instance_type = "m5.large"
  subnet_id     = "${module.vpc.private_subnets[0]}"
  key_name      = "${aws_key_pair.crash-nonprod-deployer-julia.key_name}"
  tags = {
      Name = "ansnode3-offline",
      Environment = "offline",
      Role = "ansnode"
  }
  vpc_security_group_ids = [
    "${aws_security_group.talk_to_assets.id}",
    "${aws_security_group.ephemeral_node.id}",
    "${aws_security_group.ephemeral_private.id}",
    "${aws_security_group.has_ssh.id}"
    ]
}

