resource "aws_lb" "nlb" {
  name = "${var.environment}-loadbalancer"

  internal           = false
  load_balancer_type = "network"
  enable_cross_zone_load_balancing = true

  subnets = data.aws_subnet_ids.public_subnets.ids

  tags = {
    Environment = var.environment
  }
}


resource "aws_lb_listener" "ingress" {
  load_balancer_arn = aws_lb.nlb.arn

  for_each = local.port_mapping

  port     = lookup(each.value, "port")
  protocol = lookup(each.value, "protocol")

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nodes[each.key].arn
  }
}


resource "aws_lb_target_group" "nodes" {
  for_each = local.port_mapping

  name = "${var.environment}-${var.target_role}s-${each.key}"

  vpc_id      = data.aws_vpc.this.id
  target_type = "instance"
  port        = lookup(each.value, "node_port")
  protocol    = lookup(each.value, "protocol")

  // docs: https://docs.aws.amazon.com/elasticloadbalancing/latest/network/target-group-health-checks.html
  //
  health_check {
    protocol = "TCP"
    port     = lookup(each.value, "node_port")
    interval = 30 // NOTE: 10 or 30 seconds
    # NOTE: defaults to 10 for TCP and is not allowed to be set
    # timeout  = 10
  }

  tags = {
    Environment = var.environment
  }
}

resource "aws_lb_target_group_attachment" "every_port_on_each_instance" {
  for_each = {
    for pair in setproduct(keys(local.port_mapping), data.aws_instances.nodes.ids) :
    "${pair[0]}:${pair[1]}" => {
      mapping_name = pair[0]
      instance_id  = pair[1]
    }
  }

  target_group_arn = aws_lb_target_group.nodes[each.value.mapping_name].arn
  port             = aws_lb_target_group.nodes[each.value.mapping_name].port
  target_id        = each.value.instance_id
}
