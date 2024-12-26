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

#region VPC
## original unused
data "aws_vpc" "default" {
  default = true // just use defaults
}

## new, module-based
module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs            = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
#endregion

// "aws_instance" is the resource type. these type correspond to actual resources depending on the provider.
// "blog" is the name terraform will use for this resource.
// aws creates a default VPC for each account, and here we just use the default
resource "aws_instance" "blog" {
  ami                    = data.aws_ami.app_ami.id // ami = basic image to use
  instance_type          = var.instance_type
  vpc_security_group_ids = [module.blog_sg.security_group_id]

  subnet_id = module.blog_vpc.public_subnets[0] # get first subnet

  tags = {
    Name = "HelloWorld"
  }
}

// a module is a group of resources
module "blog_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.2.0"
  name    = "blog"

  # vpc_id              = data.aws_vpc.default.id // from the data block above # old
  vpc_id              = module.blog_vpc.vpc_id
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"] // = open to everything
  egress_rules        = ["all-all"]
  egress_cidr_blocks  = ["0.0.0.0/0"] // = open to everything
}

