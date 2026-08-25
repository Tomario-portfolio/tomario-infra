output "tfstate_bucket_name" {
  description = "envs/prod/*/main.tf の backend bucket に設定する値"
  value       = aws_s3_bucket.tfstate.bucket
}

output "github_actions_role_arn" {
  description = "tomario-infra の GitHub Secrets AWS_ROLE_ARN_PROD に設定する値"
  value       = aws_iam_role.github_actions.arn
}

output "github_actions_readonly_role_arn" {
  description = "tomario-infra の GitHub Secrets AWS_ROLE_ARN_PROD_READONLY（リポジトリレベル、Environment紐付け無し）に設定する値。CI(plan)専用、Required reviewersの承認ゲートを経由しない"
  value       = aws_iam_role.github_actions_readonly.arn
}

output "github_actions_app_role_arn" {
  description = "tomario-app の GitHub Secrets AWS_ROLE_ARN_PROD に設定する値"
  value       = aws_iam_role.github_actions_app.arn
}
