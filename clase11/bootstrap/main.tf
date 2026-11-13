provider "aws" {
  region  = "us-east-1"
  profile = "terraform"

  default_tags {
    tags = {
      Proyecto = "clase11-lab-iac"
      Gestion  = "terraform-bootstrap"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  state_bucket_name = "clase11-tfstate-${data.aws_caller_identity.current.account_id}"
}

# Bucket donde infra/ guardará su estado
resource "aws_s3_bucket" "tfstate" {
  bucket = local.state_bucket_name
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# El provider OIDC de GitHub ya existe en la cuenta (clase 10): se lee, no se crea
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  # Formato con IDs numéricos, como el que emite el token real de este repo
  github_sub = "repo:sebacorreacalamuchita@26768969/devops-ia-2026@1433750616:ref:refs/heads/develop"
}

resource "aws_iam_role" "github_actions" {
  name = "github-deploy-clase11"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = data.aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = local.github_sub
        }
      }
    }]
  })
}

# Permisos de DEMO: en producción habría que acotarlos por recurso
resource "aws_iam_role_policy" "github_actions" {
  name = "terraform-lab-clase11"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EstadoTerraform"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = [aws_s3_bucket.tfstate.arn, "${aws_s3_bucket.tfstate.arn}/*"]
      },
      {
        Sid      = "ServiciosDelLab"
        Effect   = "Allow"
        Action   = ["ec2:*", "s3:*", "logs:*", "ssm:GetParameter", "ssm:GetParameters"]
        Resource = "*"
      }
    ]
  })
}
