# tomario-infra

ホテル予約システム「Tomario」の AWS インフラを管理する Terraform リポジトリです。

## アーキテクチャ

![アーキテクチャ構成図](https://raw.githubusercontent.com/Tomario-portfolio/tomario-workspace/main/reference/architecture.drawio.png)

```
ユーザー
  ↓ HTTPS
CloudFront
  ├── /* → S3（静的ファイル: HTML/CSS/JS）
  └── /api/* → ALB
                 ↓
              EC2（Flask API）
                 ↓
              RDS（MySQL 8.0）
```

### 使用サービス

| カテゴリ | サービス | 用途 |
|---|---|---|
| ネットワーク | VPC / Subnet / IGW / Route Table | ネットワーク分離 |
| フロントエンド | CloudFront / S3 | 静的ファイル配信 |
| バックエンド | ALB / ASG / EC2 / IAM | Flask API |
| データベース | RDS（MySQL 8.0） | データ永続化 |
| セキュリティ | Security Group / Secrets Manager | アクセス制御・認証情報管理 |
| 監視 | CloudWatch / SNS | アラーム通知 |
| 運用 | Systems Manager（Session Manager） | EC2 へのセキュアなアクセス |

---

## ディレクトリ構成

```
tomario-infra/
├── envs/
│   └── dev/              # 環境ごとの設定
│       ├── main.tf       # モジュール呼び出し・プロバイダー設定
│       └── variables.tf
├── modules/
│   ├── network/          # VPC・サブネット・IGW・ルートテーブル
│   ├── backend/          # ALB・EC2（ASG+LT）・IAM・SG
│   ├── database/         # RDS・SG
│   ├── frontend/         # CloudFront・S3
│   └── monitoring/       # CloudWatch アラーム・SNS
└── .github/
    └── workflows/
        ├── infra-ci.yml  # PR 時: plan / merge 時: apply
        ├── cost-stop.yml # リソース停止（コスト削減）
        └── cost-start.yml# リソース起動
```

---

## CI/CD

### infra-ci.yml

| トリガー | 実行内容 |
|---|---|
| PR（envs/** / modules/**） | terraform fmt / validate / plan |
| main へのマージ | terraform apply |

### cost-stop.yml / cost-start.yml

コスト削減のため、使わないときにリソースを手動で停止・起動できます。

**停止（cost-stop）：**
1. ALB・ASG・EC2 を削除（`terraform destroy -target`）
2. RDS を停止

**起動（cost-start）：**
1. RDS を起動・待機
2. ALB・ASG・EC2 を再作成（`terraform apply -target=module.backend`）
   - EC2 起動時に `user_data` が自動実行され Flask アプリがセットアップされる

---

## セットアップ

### 前提条件

- Terraform 1.5+
- AWS CLI（ap-northeast-1 にアクセス可能なプロファイル）
- GitHub Actions 用 OIDC IAM ロール（`AWS_ROLE_ARN`）
- S3 バケット（tfstate 管理用: `tomario-tfstate-shared-bucket`）

### GitHub Secrets

| Secret 名 | 内容 |
|---|---|
| `AWS_ROLE_ARN` | GitHub Actions が AssumeRole する IAM ロールの ARN |
| `ALARM_EMAIL` | CloudWatch アラーム通知先メールアドレス |

### ローカルでの実行

```bash
cd envs/dev
terraform init
terraform plan -var="alarm_email=your@email.com"
terraform apply -var="alarm_email=your@email.com"
```

---

## モジュール間の依存関係

```
network
  ├── backend（vpc_id, public_subnet_ids）
  │     └── database（ec2_sg_id）
  ├── database（vpc_id, private_subnet_ids）
  ├── frontend（alb_dns_name）
  └── monitoring（backend・database の output 経由）
```

---

## アプリリポジトリ

フロントエンド・バックエンドのコードは別リポジトリで管理しています。

→ [tomario-app](https://github.com/Tomario-portfolio/tomario-app)
