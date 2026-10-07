resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "tomario-${var.env}-app"
  }
}

resource "aws_ecr_repository_policy" "cross_account_pull" {
  count      = length(var.cross_account_pull_role_arns) > 0 ? 1 : 0
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "CrossAccountPromotePull"
      Effect    = "Allow"
      Principal = { AWS = var.cross_account_pull_role_arns }
      Action = [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
      ]
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  # ECRのライフサイクルルールは、優先度の高いルールに一致したイメージを、それより低いルールでは削除しない。
  # ECSタスク定義の初期イメージ（var.bootstrap_image、bootstrapタグ）は、cost-startでECSサービスを
  # 作り直すたびに参照されるため、優先度1のルールで保護する。保護しないと「最新5世代のみ保持」で
  # 古いイメージとして削除され、cost-start後のタスクがCannotPullContainerErrorで起動できなくなる（2026-10-07に発生）
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "bootstrapタグ（ECSタスク定義の初期イメージ）を保護"
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["bootstrap"]
          countType      = "imageCountMoreThan"
          countNumber    = 1
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "最新5世代のみ保持"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
