# data sources get information about deployed infrastructure
# they're like variables but allow retrieving data from other places
data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.ami_filter.name]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [var.ami_filter.owner]
}

module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.environment.name}-vpc"
  cidr = "${var.environment.network_prefix}.0.0/16"

  azs = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets = [
    "${var.environment.network_prefix}.101.0/24",
    "${var.environment.network_prefix}.102.0/24",
    "${var.environment.network_prefix}.103.0/24"
  ]

  tags = {
    Terraform   = "true"
    Environment = var.environment.name
  }
}

# "aws_instance" is the resource type. these type correspond to actual resources depending on the provider.
# "blog" is the name terraform will use for this resource.
# aws creates a default VPC for each account, and here we just use the default
# resource "aws_instance" "blog" {
#   ami                    = data.aws_ami.app_ami.id # ami = basic image to use
#   instance_type          = var.instance_type
#   vpc_security_group_ids = [module.blog_sg.security_group_id]

#   subnet_id = module.blog_vpc.public_subnets[0] # get first subnet

#   tags = {
#     Name = "HelloWorld"
#   }
# }

# Replaces the instance above
module "blog_autoscaling" {
  source   = "terraform-aws-modules/autoscaling/aws"
  version  = "8.0.1"
  name     = "${var.environment.name}-blog"
  min_size = var.asg_min_size
  max_size = var.asg_max_size
  # not configuring autoscaling per load

  # network config
  vpc_zone_identifier = module.blog_vpc.public_subnets
  traffic_source_attachments = {
    alb_target_group = {
      type                      = "elb"
      traffic_source_identifier = module.blog_alb.target_groups.ex-instance.arn
    }
  }
  security_groups = [module.blog_sg.security_group_id]

  # application config
  image_id      = data.aws_ami.app_ami.id
  instance_type = var.instance_type

  tags = {
    Name = "HelloAutoscalingWorld"
  }
}

module "blog_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.0"

  name            = "${var.environment.name}-blog-alb" # will be used by aws
  enable_deletion_protection = false
  vpc_id          = module.blog_vpc.vpc_id
  subnets         = module.blog_vpc.public_subnets
  security_groups = [module.blog_sg.security_group_id]

  # Security Group
  #todo: figure out how to use the same rules as in module.blog_sg, maybe refactor them out?
  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "HTTP web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
    all_https = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      description = "HTTPS web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "${var.environment.network_prefix}.0.0/16"
    }
  }

  listeners = {
    ex-http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "ex-instance"
      }
    }
  }

  target_groups = { # where to send the traffic to
    ex-instance = {
      name_prefix = "${var.environment.name}" # just to make it easier to identify
      protocol    = "HTTP"
      port        = 80
      target_type = "instance"
      create_attachment = false
    }
  }

  tags = {
    Environment = var.environment.name
    Project     = "A blog"
  }
}

module "blog_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.2.0"
  name    = "${var.environment.name}-blog" # good to add env to name of resources in order to avoid name collision

  vpc_id              = module.blog_vpc.vpc_id
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"] # = open to everything
  egress_rules        = ["all-all"]
  egress_cidr_blocks  = ["0.0.0.0/0"]
}

