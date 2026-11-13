data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = "us-east-1"
}

data "aws_iam_policy_document" "deploy" {
  # EC2 y Security Groups, solo en la región del lab
  statement {
    sid       = "Ec2Lab"
    actions   = ["ec2:*"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [local.region]
    }
  }

  # Rol e instance profile de SSM para la EC2, solo con prefijo clase10-
  statement {
    sid = "IamForInstance"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:TagRole",
      "iam:UpdateAssumeRolePolicy", "iam:AttachRolePolicy", "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies", "iam:ListRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile", "iam:GetInstanceProfile",
      "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
    ]
    resources = [
      "arn:aws:iam::${local.account_id}:role/clase10-*",
      "arn:aws:iam::${local.account_id}:instance-profile/clase10-*",
    ]
  }

  statement {
    sid       = "PassRoleToEc2"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/clase10-*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com"]
    }
  }

  # SSM Run Command
  statement {
    sid     = "SsmSendCommand"
    actions = ["ssm:SendCommand"]
    resources = [
      "arn:aws:ssm:${local.region}::document/AWS-RunShellScript",
      "arn:aws:ec2:${local.region}:${local.account_id}:instance/*",
    ]
  }

  statement {
    sid = "SsmRead"
    actions = [
      "ssm:GetCommandInvocation", "ssm:ListCommandInvocations",
      "ssm:DescribeInstanceInformation",
      "ssm:GetParameter", # para resolver la AMI desde el parámetro público
    ]
    resources = ["*"]
  }
  # State remoto de Terraform
  statement {
    sid       = "TfStateList"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::clase10-tfstate-${local.account_id}"]
  }

  statement {
    sid       = "TfStateObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::clase10-tfstate-${local.account_id}/*"]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "clase10-deploy"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}
