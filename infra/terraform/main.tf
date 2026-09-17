data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "network" {
  source = "./modules/network"

  project            = var.project
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  availability_zone  = var.availability_zone
}

module "security_group" {
  source = "./modules/security_group"

  project     = var.project
  vpc_id      = module.network.vpc_id
  admin_cidrs = var.admin_cidrs
}

module "compute" {
  source = "./modules/compute"

  project           = var.project
  ami_id            = data.aws_ami.ubuntu.id
  instance_type     = var.instance_type
  subnet_id         = module.network.public_subnet_id
  security_group_id = module.security_group.sg_id
  key_name          = var.key_name
  public_key_path   = var.public_key_path
  worker_count      = var.worker_count
  root_volume_size  = var.root_volume_size
}
