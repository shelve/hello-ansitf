terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region     = var.region
  access_key = var.aws_access_key_id != "" ? var.aws_access_key_id : null
  secret_key = var.aws_secret_access_key != "" ? var.aws_secret_access_key : null
  token      = var.aws_session_token != "" ? var.aws_session_token : null
}

variable "aws_access_key_id" {
  type        = string
  description = "AWS access key ID for HCP remote runs (optional if using env vars)"
  default     = ""
  sensitive   = true
}

variable "aws_secret_access_key" {
  type        = string
  description = "AWS secret access key for HCP remote runs (optional if using env vars)"
  default     = ""
  sensitive   = true
}

variable "aws_session_token" {
  type        = string
  description = "AWS session token for temporary credentials (optional)"
  default     = ""
  sensitive   = true
}

variable "region" {
  type        = string
  description = "AWS region for demo resources"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Environment label used by inventory grouping"
  default     = "demo"
}

variable "app_name" {
  type        = string
  description = "Application name used in tags"
  default     = "aap-demo-app"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.micro"
}

variable "ssh_ingress_cidr" {
  type        = string
  description = "CIDR allowed for SSH"
  default     = "0.0.0.0/0"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_vpc" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_security_group" "demo" {
  name_prefix = "aap-demo-sg-"
  description = "Security group for AAP demo EC2"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_ingress_cidr]
  }

  ingress {
    description = "HTTP"
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
    Name        = "${var.app_name}-${var.environment}-sg"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_instance" "demo_web" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.default_vpc.ids[0]
  vpc_security_group_ids      = [aws_security_group.demo.id]
  associate_public_ip_address = true

  tags = {
    Name        = "hcp-ec2-${var.app_name}-${var.environment}"
    Environment = var.environment
    Role        = "web"
    ManagedBy   = "terraform"
  }
}

output "instance_id" {
  value = aws_instance.demo_web.id
}

output "public_ip" {
  value = aws_instance.demo_web.public_ip
}

# Shape expected by the tfc_inv outputs source.
output "ansible_host" {
  value = {
    "${aws_instance.demo_web.tags.Name}" = {
      public_ip  = aws_instance.demo_web.public_ip
      private_ip = aws_instance.demo_web.private_ip
      env        = var.environment
      role       = "web"
    }
  }
}
