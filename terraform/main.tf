resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "ALB-demo-vpc"
  }
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.mainvpc.id

  ingress {
    protocol  = -1
    self      = true
    from_port = 0
    to_port   = 0
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "alb-demo-igw"
  }
}

resource "aws_subnet" "public_subnets" {
  count                   = 2
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 4, count.index)
  availability_zone       = data.aws_availability_zones.azs.names[count.index]
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = true
  tags = {
    Name = "alb-demo-pub-subnet-${count.index + 1}"
  }
}

resource "aws_instance" "flask_app" {
  instance_type   = "t3.micro"
  ami             = "ami-05ffe3c48a9991133"
  security_groups = [aws_default_security_group.default.id]
  subnet_id       = aws_subnet.public_subnets[0].id
  user_data       = file("../app/start.sh")
  tags = {
    Name = "demo-flask-app"
  }
}

resource "aws_instance" "web_app" {
  ami             = "ami-05ffe3c48a9991133"
  instance_type   = "t3.micro"
  security_groups = [aws_default_security_group.default.id]
  subnet_id       = aws_subnet.public_subnets[1].id
  user_data       = file("../web/start.sh")
  tags = {
    Name = "demo-web-app"
  }
}

resource "aws_lb" "demo_lb" {
  name               = "demo-alb"
  load_balancer_type = "application"
  subnets            = aws_subnet.public_subnets[*].id
  internal           = false
  security_groups    = [aws_default_security_group.default.id]
}

resource "aws_lb_target_group" "flask_tg" {
  name     = "flask-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check {
    path                = "/api"
    port                = "5000"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 10
  }
}

resource "aws_lb_target_group" "web_tg" {
  name     = "web-tg"
  protocol = "HTTP"
  port     = 80
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_target_group_attachment" "flask_attach" {
  target_group_arn = aws_lb_target_group.flask_tg.arn
  target_id        = aws_instance.flask_app.id
  port             = 5000
}

resource "aws_lb_target_group_attachment" "web_attach" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web_app.id
  port             = 80

}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.demo_lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

resource "aws_lb_listener_rule" "api_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.flask_tg.arn
  }
  condition {
    path_pattern {
      values = ["/api*"]
    }
  }
}