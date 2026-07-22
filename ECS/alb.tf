# Application Load Balancer setup to expose the ECS service to the internet.

# 1. Security Group for the ALB (allow HTTP from anywhere)
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow inbound HTTP from the internet"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

# 2. Security Group for the ECS tasks (allow traffic only from the ALB)
resource "aws_security_group" "ecs_sg" {
  name        = "ecs-tasks-sg"
  description = "Allow inbound traffic from the ALB only"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description     = "App port from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-tasks-sg"
  }
}

# 3. The Application Load Balancer (lives in the public subnets)
resource "aws_lb" "app_alb" {
  name               = "production-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet.id, aws_subnet.public_subnet_2.id]

  tags = {
    Name = "production-alb"
  }
}

# 4. Target Group (target_type "ip" is required for Fargate/awsvpc)
resource "aws_lb_target_group" "app_tg" {
  name        = "production-app-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main_vpc.id
  target_type = "ip"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "production-app-tg"
  }
}

# 5. Listener (forwards HTTP:80 to the target group)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# 6. Rule: allow /admin/* ONLY from the trusted IP (evaluated first)
resource "aws_lb_listener_rule" "admin_allow" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }

  condition {
    path_pattern {
      values = ["/admin/*"]
    }
  }

  condition {
    source_ip {
      values = ["203.139.59.153/32"]
    }
  }
}

# 7. Rule: any other /admin/* request gets a hard-coded 403
resource "aws_lb_listener_rule" "admin_deny" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/html"
      status_code  = "403"
      message_body = "<html><body><h1>403 Access Denied</h1></body></html>"
    }
  }

  condition {
    path_pattern {
      values = ["/admin/*"]
    }
  }
}

# Handy output: the public URL of the load balancer
output "alb_dns_name" {
  value       = aws_lb.app_alb.dns_name
  description = "Public DNS name of the Application Load Balancer"
}
