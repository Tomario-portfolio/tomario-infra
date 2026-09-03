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
  region  = var.aws_region
  profile = "tomario-prod"
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
# nonprodと違い、GitHub Environment「prod」経由のワークフローだけが引き受けられるよう信頼条件を絞る
# （Environment側にRequired reviewersを設定すれば、承認されたデプロイだけがこのロールを使える）

resource "aws_iam_role" "github_actions" {
  name = "github-actions-terraform-prod"

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
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:environment:${var.github_environment}"
        }
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

# Terraform実行に必要なポリシー（nonprod側と同一内容。使用サービスを明示的に列挙）
resource "aws_iam_role_policy" "github_actions" {
  name = "github-actions-terraform-prod-policy"
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

# ---- CI（plan専用）用ロール ----
# terraform-terraform（apply）ロールと違い、GitHub Environment「prod」に絞らずリポジトリ全体を信頼する
# （Required reviewersの承認を経ずにPR作成・push時点でplanを実行できるようにするため）。
# その代わり読み取り専用（ReadOnlyAccess）に絞り、apply系の操作は一切できないようにする。

resource "aws_iam_role" "github_actions_readonly" {
  name = "github-actions-terraform-prod-readonly"

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

resource "aws_iam_role_policy_attachment" "github_actions_readonly" {
  role       = aws_iam_role.github_actions_readonly.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# ReadOnlyAccessにはs3:PutObject/DeleteObjectが含まれず、terraform planでもS3ネイティブの
# stateロック（use_lockfile = true、.tflockファイルへの書き込み）に失敗するため、
# ロックファイルのみに絞って書き込み権限を追加する（state本体への書き込みは許可しない）
resource "aws_iam_role_policy" "github_actions_readonly_state_lock" {
  name = "github-actions-terraform-prod-readonly-state-lock"
  role = aws_iam_role.github_actions_readonly.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:DeleteObject"]
      Resource = "arn:aws:s3:::${var.tfstate_bucket_name}/*.tflock"
    }]
  })
}

# ---- アプリデプロイ用ロール（tomario-app） ----
# 最小権限：ECR push + ECS update-service のみ。こちらもGitHub Environment「prod」に絞る

resource "aws_iam_role" "github_actions_app" {
  name = "github-actions-app-deploy-prod"

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
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_app_repo}:environment:${var.github_environment}"
        }
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_actions_app" {
  name = "github-actions-app-deploy-prod-policy"
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
      },
      {
        # フロントエンド静的ファイルのデプロイ（deploy.ymlのpromote-to-productionジョブ用）
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:PutObject",
          "s3:DeleteObject",
        ]
        Resource = [
          "arn:aws:s3:::tomario-production-frontend",
          "arn:aws:s3:::tomario-production-frontend/*",
        ]
      },
      {
        # デプロイ後のCloudFrontキャッシュ無効化
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
        ]
        Resource = [
          "arn:aws:cloudfront::236782813946:distribution/E16RCKYF5065BQ",
        ]
      }
    ]
  })
}
