provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Proyecto = "lab-iac"
      Entorno  = var.environment
      Gestion  = "terraform"
    }
  }
}

locals {
  name_prefix = "lab-iac-${var.environment}"
}

# --- Datos existentes: VPC por defecto, subnet y AMI ---
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# --- Security Group: HTTP 80 solo desde la IP autorizada, sin SSH ---
resource "aws_security_group" "web" {
  name        = "${local.name_prefix}-web-sg"
  description = "HTTP desde IP autorizada"
  vpc_id      = data.aws_vpc.default.id

  # Si el SG se reemplaza, crea el nuevo antes de borrar el viejo
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id
  description       = "HTTP desde la IP autorizada"
  cidr_ipv4         = var.http_cidr
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.web.id
  description       = "Salida libre (instalar paquetes)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# --- EC2 con Nginx ---
resource "aws_instance" "web" {
  ami                         = data.aws_ssm_parameter.al2023.insecure_value
  instance_type               = var.instance_type
  subnet_id                   = sort(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true

  metadata_options {
    http_tokens   = "required" # IMDSv2 obligatorio
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  user_data = <<-EOT
    #!/bin/bash
    dnf install -y nginx
    echo "<h1>Lab IaC - ${var.environment}</h1>" > /usr/share/nginx/html/index.html
    systemctl enable --now nginx
  EOT

  tags = {
    Name = "${local.name_prefix}-web"
  }
}

# --- S3 del lab: privado, cifrado y versionado ---
resource "aws_s3_bucket" "data" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- CloudWatch: log group con retención configurable ---
resource "aws_cloudwatch_log_group" "app" {
  name              = "/lab/${local.name_prefix}/app"
  retention_in_days = var.log_retention_days
}
