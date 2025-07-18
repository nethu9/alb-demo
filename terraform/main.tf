resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "ALB-demo-vpc"
  }
}

resource "aws_key_pair" "demo_alb" {
    key_name = "ssh-key"
    public_key = file("./ssh-key.pub")
}

resource "aws_security_group" "just-for-testing" {
  vpc_id = aws_vpc.main.id
  name = "just-for-testing-sg"
  tags = {
    Name = "just-for-testing-sg"
  }

  ingress {
    from_port = 0
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "-1"
  }
  egress {
    from_port = 0
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "-1"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "alb-demo-public-rt"
  }
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_association" {
  count          = length(aws_subnet.public_subnets)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
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
  security_groups = [aws_security_group.just-for-testing.id]
  subnet_id       = aws_subnet.public_subnets[0].id
  user_data       = file("../app/start.sh")
  key_name = aws_key_pair.demo_alb.key_name
  tags = {
    Name = "demo-flask-app"
  }
}

resource "aws_instance" "web_app" {
  ami             = "ami-05ffe3c48a9991133"
  instance_type   = "t3.micro"
  security_groups = [aws_security_group.just-for-testing.id]
  subnet_id       = aws_subnet.public_subnets[1].id
  user_data       = file("../web/start.sh")
  key_name = aws_key_pair.demo_alb.key_name
  tags = {
    Name = "demo-web-app"
  }
}

resource "aws_lb" "demo_lb" {
  name               = "demo-alb"
  load_balancer_type = "application"
  subnets            = aws_subnet.public_subnets[*].id
  internal           = false
  security_groups    = [aws_security_group.just-for-testing.id]
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

resource "aws_lb_target_group_attachment" "flask_attach" { # registering
  target_group_arn = aws_lb_target_group.flask_tg.arn
  target_id        = aws_instance.flask_app.id
  port             = 5000
}

resource "aws_lb_target_group_attachment" "web_attach" { #registering
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