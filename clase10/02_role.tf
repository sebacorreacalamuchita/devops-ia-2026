variable "github_repo" {
  description = "Damianca/devops-ia-2026"
  type        = string
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Solo main y ejecuciones manuales (workflow_dispatch desde main).
    # Los PR tienen sub "repo:...:pull_request" y quedan afuera.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name               = "github-deploy-clase10"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

output "role_arn" {
  value = aws_iam_role.github_deploy.arn
}
