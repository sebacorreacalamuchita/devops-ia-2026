terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "clase10-tfstate-058264073348"
    key          = "clase10/infra.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = { Proyecto = "clase10", ManagedBy = "terraform" }
  }
}

# AMI Amazon Linux 2023 (ya trae SSM Agent)
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_vpc" "default" {
  default = true
}

# Rol de la instancia para que SSM pueda administrarla
resource "aws_iam_role" "ec2" {
  name = "clase10-ec2-ssm"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "clase10-ec2-ssm"
  role = aws_iam_role.ec2.name
}

# Solo HTTP; sin puerto 22
resource "aws_security_group" "web" {
  name        = "clase10-web"
  description = "HTTP para Nginx"
  vpc_id      = data.aws_vpc.default.id

  ingress {
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
}

resource "aws_instance" "web" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = "t3.micro"
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true

  metadata_options {
    http_tokens = "required" # IMDSv2
  }

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y nginx
    systemctl enable --now nginx
  EOF

  tags = { Name = "clase10-web" }
}

output "instance_id" {
  value = aws_instance.web.id
}

output "public_ip" {
  value = aws_instance.web.public_ip
}
