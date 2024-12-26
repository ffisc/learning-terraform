// data sources get information about deployed infrastructure
data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}

data "aws_vpc" "default" {
  default = true // just use defaults
}

// "aws_instance" is the resource type. these type correspond to actual resources depending on the provider.
// "blog" is the name terraform will use for this resource.
// aws creates a default VPC for each account, and here we just use the default
resource "aws_instance" "blog" {
  ami           = data.aws_ami.app_ami.id // ami = basic image to use
  instance_type = var.instance_type

  vpc_security_group_ids = [module.blog_sg.security_group_id]

  tags = {
    Name = "HelloWorld"
  }
}

// a module is a group of resources
module "blog_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.2.0"
  name    = "blog-from-module"

  vpc_id              = data.aws_vpc.default.id // from the data block above
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"] // = open to everything
  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"] // = open to everything
}

resource "aws_security_group" "blog" {
  name        = "blog" // not required but prevents TF from generating a random name
  description = "Allow http and https in. Allow everything out"

  vpc_id = data.aws_vpc.default.id // from the data block above
}

resource "aws_security_group_rule" "blog_http_in" {
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"] // = open to everything

  security_group_id = aws_security_group.blog.id
}

resource "aws_security_group_rule" "blog_https_in" {
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.blog.id
}

resource "aws_security_group_rule" "blog_everything_out" {
  type        = "egress"
  from_port   = 0    // all ports
  to_port     = 0    // all ports
  protocol    = "-1" // = all protocols
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.blog.id
}
