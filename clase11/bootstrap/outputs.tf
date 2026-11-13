output "tf_state_bucket" {
  description = "Valor para el Secret TF_STATE_BUCKET de GitHub"
  value       = aws_s3_bucket.tfstate.id
}

output "aws_role_arn" {
  description = "Valor para el Secret AWS_ROLE_ARN de GitHub"
  value       = aws_iam_role.github_actions.arn
}
