terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# tfstate保管用S3バケット
resource "aws_s3_bucket" "tfstate" {
  bucket = var.tfstate_bucket_name
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

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# GitHub Actions OIDC Provider
resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

# ---- インフラCI用ロール（tomario-infra） ----

resource "aws_iam_role" "github_actions" {
  name = "github-actions-terraform"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github_actions.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
        }
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

# Terraform実行に必要なポリシー（使用サービスを明示的に列挙）
resource "aws_iam_role_policy" "github_actions" {
  name = "github-actions-terraform-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # ネットワーク
          "ec2:*",
          # ロードバランサー
          "elasticloadbalancing:*",
          # Auto Scaling
          "autoscaling:*",
          "application-autoscaling:*",
          # コンテナ
          "ecr:*",
          "ecs:*",
          # デプロイ（Blue/Greenデプロイ用）
          "codedeploy:*",
          # WAF
          "wafv2:*",
          # データベース
          "rds:*",
          # ストレージ
          "s3:*",
          # CDN
          "cloudfront:*",
          # DNS
          "route53:*",
          # 証明書（CloudFront・ALBのHTTPS化で使用）
          "acm:*",
          # 監視
          "cloudwatch:*",
          "logs:*",
          # セキュリティ
          "cloudtrail:*",
          "guardduty:*",
          # コスト管理
          "budgets:*",
          "ce:*",
          # アラーム通知
          "sns:*",
          # SSM Session Manager
          "ssm:*",
          # RDSパスワード自動管理（Secrets Manager + KMS）
          "secretsmanager:*",
          "kms:*",
          # IAM（ECSタスクロール・サービスリンクロール作成に必要）
          "iam:GetRole",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:UpdateRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:ListRoles",
          "iam:PassRole",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:GetInstanceProfile",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:ListInstanceProfilesForRole",
          "iam:TagInstanceProfile",
          "iam:UntagInstanceProfile",
          "iam:CreateServiceLinkedRole",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
        ]
        Resource = "*"
      }
    ]
  })
}

# ---- アプリデプロイ用ロール（tomario-app） ----
# 最小権限：ECR push + ECS update-service のみ

resource "aws_iam_role" "github_actions_app" {
  name = "github-actions-app-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github_actions.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_app_repo}:*"
        }
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_actions_app" {
  name = "github-actions-app-deploy-policy"
  role = aws_iam_role.github_actions_app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # ECRへのdocker push
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          # deploy.ymlの既存イメージタグ存在チェックに必要（無いと常に「存在しない」判定になり、
          # IMMUTABLE設定の既存タグへ再pushしようとして失敗する）
          "ecr:DescribeImages",
          # ECSサービスの更新・タスク定義の登録
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTasks",
          # タスク定義にIAMロールを渡す権限
          "iam:PassRole",
          # Blue/Greenデプロイ（CodeDeploy）のデプロイ実行・監視のみ。アプリ作成/設定変更はTerraform側（infra）で行う
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:GetApplicationRevision",
          "codedeploy:RegisterApplicationRevision",
        ]
        Resource = "*"
      }
    ]
  })
}
