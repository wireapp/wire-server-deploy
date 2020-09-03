resource "aws_lb" "nlb" {
  name = "${var.environment}-loadbalancer"

  internal                         = false
  load_balancer_type               = "network"
  enable_cross_zone_load_balancing = true

  subnets = var.subnet_ids

  tags = {
    Environment = var.environment
  }
}


resource "aws_lb_listener" "ingress-http" {
  load_balancer_arn = aws_lb.nlb.arn

  port     = 80
  protocol = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nodes-http.arn
  }
}


resource "aws_lb_target_group" "nodes-http" {
  name = "${var.environment}-nodes-http"

  vpc_id = data.aws_vpc.this.id

  # NOTE: using "instance" - as an alternative type - does not work due to the way security groups are being
  #       configured (VPC CIDR vs NLB network IP addresses)
  # SRC:  https://docs.aws.amazon.com/elasticloadbalancing/latest/network/target-group-register-targets.html#target-security-groups
  # DOC:  https://docs.aws.amazon.com/elasticloadbalancing/latest/network/load-balancer-target-groups.html
  target_type = "ip"
  port        = var.node_port_http
  protocol    = "TCP"

  # docs: https://docs.aws.amazon.com/elasticloadbalancing/latest/network/target-group-health-checks.html
  #
  health_check {
    protocol = "TCP"
    port     = var.node_port_http
    interval = 30  # NOTE: 10 or 30 seconds
    # NOTE: defaults to 10 for TCP and is not allowed to be set when using an NLB
    # timeout  = 10
  }

  tags = {
    Environment = var.environment
  }
}


resource "aws_lb_target_group_attachment" "each-node-http" {
  count = length(var.node_ips)

  target_group_arn = aws_lb_target_group.nodes-http.arn
  port             = aws_lb_target_group.nodes-http.port
  target_id        = var.node_ips[count.index]
}


resource "aws_lb_listener" "ingress-https" {
  load_balancer_arn = aws_lb.nlb.arn

  port     = 443
  protocol = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nodes-https.arn
  }
}


resource "aws_lb_target_group" "nodes-https" {
  name = "${var.environment}-nodes-https"

  vpc_id = data.aws_vpc.this.id

  target_type = "ip"
  port        = var.node_port_https
  protocol    = "TCP"

  health_check {
    protocol = "TCP"
    port     = var.node_port_https
    interval = 30
  }

  tags = {
    Environment = var.environment
  }
}


resource "aws_lb_target_group_attachment" "each-node-https" {
  count = length(var.node_ips)

  target_group_arn = aws_lb_target_group.nodes-https.arn
  port             = aws_lb_target_group.nodes-https.port
  target_id        = var.node_ips[count.index]
}
