data "aws_lb" "this" {
  count = local.use_alb_rule ? 1 : 0
  name  = var.alb_rule.alb_name
}

data "aws_lb_listener" "http" {
  count             = local.use_alb_rule ? 1 : 0
  load_balancer_arn = data.aws_lb.this[0].arn
  port              = 80
}

data "aws_instances" "eks_nodes" {
  count = local.use_alb_rule ? 1 : 0

  filter {
    name   = "tag:kubernetes.io/cluster/${var.alb_rule.cluster_name}"
    values = ["owned"]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

resource "aws_lb_target_group" "grafana" {
  count       = local.use_alb_rule ? 1 : 0
  name        = "${var.helm_release_name}-tg"
  port        = var.alb_rule.node_port
  protocol    = "HTTP"
  vpc_id      = data.aws_lb.this[0].vpc_id
  target_type = "instance"

  health_check {
    path                = "/${local.subpath}/api/health"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }
}

resource "aws_lb_target_group_attachment" "nodes" {
  for_each = local.use_alb_rule ? toset(data.aws_instances.eks_nodes[0].ids) : toset([])

  target_group_arn = aws_lb_target_group.grafana[0].arn
  target_id        = each.value
  port             = var.alb_rule.node_port
}

resource "aws_lb_listener_rule" "grafana" {
  count        = local.use_alb_rule ? 1 : 0
  listener_arn = data.aws_lb_listener.http[0].arn
  priority     = var.alb_rule.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana[0].arn
  }

  condition {
    path_pattern {
      values = ["${var.alb_rule.path}", "${var.alb_rule.path}/*"]
    }
  }
}
