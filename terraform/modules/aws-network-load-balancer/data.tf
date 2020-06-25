data "aws_vpc" "this" {
  filter {
    name   = "tag:Environment"
    values = [ var.environment ]
  }
}

data "aws_subnet_ids" "public_subnets" {
  vpc_id = data.aws_vpc.this.id

  filter {
    name   = "tag:Environment"
    values = [ var.environment ]
  }

  filter {
    name   = "tag:Routability"
    values = ["public"]
  }
}

data "aws_instances" "nodes" {
  filter {
    name   = "tag:Environment"
    values = [ var.environment ]
  }

  filter {
    name   = "tag:Role"
    values = [ var.target_role ]
  }

  instance_state_names = ["running"]
}

data "aws_instance" "nodes" {
  for_each = { for k, v in data.aws_instances.nodes.ids : v => v }

  instance_id = each.value
}
