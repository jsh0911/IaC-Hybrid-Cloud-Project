########################################
# Public ALB -> Private Jenkins (8080)
# Access via AWS ALB DNS name
########################################

# ALB SG (internet-facing)
resource "aws_security_group" "jenkins_alb" {
  name_prefix = "${var.name_prefix}-jenkins-alb-"
  description = "ALB SG for Jenkins"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.admin_cidrs
    description = "HTTP from allowed CIDRs"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound"
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-jenkins-alb-sg" })
}

# Jenkins SG에 "ALB에서만 8080 허용" 인바운드 규칙 추가
resource "aws_security_group_rule" "jenkins_from_alb_8080" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = module.jenkins.security_group_id
  source_security_group_id = aws_security_group.jenkins_alb.id
  description              = "Allow Jenkins 8080 from ALB only"
}

resource "aws_lb" "jenkins" {
  name               = "${var.name_prefix}-jenkins-alb"
  load_balancer_type = "application"
  internal           = false

  security_groups = [aws_security_group.jenkins_alb.id]
  subnets         = [aws_subnet.public_a.id, aws_subnet.public_c.id]

  tags = merge(var.tags, { Name = "${var.name_prefix}-jenkins-alb" })
}

resource "aws_lb_target_group" "jenkins" {
  name        = "${var.name_prefix}-jenkins-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  # Jenkins는 초기엔 redirect(302)도 나올 수 있어서 200~399로 체크
  health_check {
    protocol            = "HTTP"
    path                = "/login"
    matcher             = "200-399"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-jenkins-tg" })
}

resource "aws_lb_target_group_attachment" "jenkins" {
  target_group_arn = aws_lb_target_group.jenkins.arn
  target_id        = module.jenkins.instance_id
  port             = 8080
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.jenkins.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins.arn
  }
}

output "jenkins_alb_dns_name" {
  value = aws_lb.jenkins.dns_name
}

output "jenkins_url" {
  value = "http://${aws_lb.jenkins.dns_name}"
}
