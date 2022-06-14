provider "aws" {
  region = "eu-central-1"

  default_tags {
    tags = {
      lab = "aws-lb-net-asg"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.0"

  name = "main-vpc"
  cidr = "10.0.0.0/16"

  azs                  = data.aws_availability_zones.available.names
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_dns_hostnames = true
  enable_dns_support   = true
}

data "aws_ami" "amazon-linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

#tfsec:ignore:aws-autoscaling-no-public-ip
#tfsec:ignore:aws-autoscaling-enforce-http-token-imds
#tfsec:ignore:aws-autoscaling-enable-at-rest-encryption
resource "aws_launch_configuration" "terra" {
  name_prefix                 = "terraform-aws-asg-"
  image_id                    = data.aws_ami.amazon-linux.id
  instance_type               = "t2.micro"
  user_data                   = file("user-data.sh")
  security_groups             = [aws_security_group.terra_instance.id]
  associate_public_ip_address = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "terra" {
  name                 = "terra"
  min_size             = 1
  max_size             = 3
  desired_capacity     = 1
  launch_configuration = aws_launch_configuration.terra.name
  vpc_zone_identifier  = module.vpc.public_subnets

  tag {
    key                 = "Name"
    value               = "Asg"
    propagate_at_launch = true
  }
}

resource "aws_lb" "terra" {
  name               = "net-lb"
  internal           = false #tfsec:ignore:aws-elb-alb-not-public
  load_balancer_type = "network"
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_listener" "terra" {
  load_balancer_arn = aws_lb.terra.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.terra.arn
  }
}

resource "aws_lb_target_group" "terra" {
  name        = "asg-target-group"
  port        = 31555
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = module.vpc.vpc_id

  health_check {
    port                = 31555
    protocol            = "TCP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}


resource "aws_autoscaling_attachment" "terra" {
  autoscaling_group_name = aws_autoscaling_group.terra.id
  lb_target_group_arn    = aws_lb_target_group.terra.arn
}

resource "aws_security_group" "terra_instance" {

  name        = "instance-asg-sec-group"
  description = "Allow inbound to 31555/TCP"

  #tfsec:ignore:aws-vpc-no-public-ingress-sgr
  ingress {
    description     = "Allow only to 31555/TCP (httpd)"
    from_port       = 31555
    to_port         = 31555
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  #tfsec:ignore:aws-vpc-no-public-egress-sgr
  egress {
    description = "Allow outbound traffic to everyone"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = module.vpc.vpc_id
}

#tfsec:ignore:aws-vpc-no-public-ingress-sgr
resource "aws_security_group" "terra_lb" {
  name        = "lb-asg-sec-group"
  description = "Allow inbound HTTP traffic"


  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #tfsec:ignore:aws-vpc-no-public-egress-sgr
  egress {
    description = "Allow outbound traffic to everyone"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = module.vpc.vpc_id
}

resource "aws_autoscaling_schedule" "scale_out_during_business_hours" {

  scheduled_action_name  = "scale-out-during-business-hours"
  min_size               = 1
  max_size               = 3
  desired_capacity       = 1
  recurrence             = "0 8 * * 1-5"
  time_zone              = "CET"
  autoscaling_group_name = aws_autoscaling_group.terra.name
}

resource "aws_autoscaling_schedule" "scale_in_at_night" {

  scheduled_action_name  = "scale-in-at-night"
  min_size               = 0
  max_size               = 0
  desired_capacity       = 0
  recurrence             = "0 18 * * 1-5"
  time_zone              = "CET"
  autoscaling_group_name = aws_autoscaling_group.terra.name
}
