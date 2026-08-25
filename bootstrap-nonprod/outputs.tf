output "tfstate_bucket_name" {
  description = "envs/*/main.tf の backend bucket に設定する値"
  value       = aws_s3_bucket.tfstate.bucket
}

output "github_actions_role_arn" {
  description = "tomario-infra の GitHub Secrets AWS_ROLE_ARN に設定する値"
  value       = aws_iam_role.github_actions.arn
}

output "github_actions_app_role_arn" {
  description = "tomario-app の GitHub Secrets AWS_ROLE_ARN に設定する値"
  value       = aws_iam_role.github_actions_app.arn
}
