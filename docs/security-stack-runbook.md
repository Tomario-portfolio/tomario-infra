# セキュリティスタック ON/OFF 手順（production）

WAF・Security Hub・AWS Config は常時稼働コストに見合わないため、**面接活動期間の頭で一度 ON にし、活動終了時（またはポートフォリオを畳む時）に OFF に戻す**運用とする。日次の `cost-stop.yml` / `cost-start.yml` サイクルには含めない。

- Security Hub は無効化の 90 日後に findings が削除される
- AWS Config は連続した構成履歴が価値なので、日次で止めると意味が薄れる

## 対象フラグ（すべて default false）

| コンポーネント | ファイル | 変数 | 作るもの |
|---|---|---|---|
| backend | `envs/prod/production/backend/` | `enable_waf` | ALB用 Web ACL（REGIONAL）＋ ALB への association |
| frontend | `envs/prod/production/frontend/` | `enable_waf` | CloudFront用 Web ACL（CLOUDFRONT / us-east-1）＋ distribution へアタッチ |
| security | `envs/prod/production/security/` | `enable_security_hub` / `enable_config` | Security Hub + CIS 標準、AWS Config recorder + S3 + IAM ロール |

WAF の中身（`modules/waf`）：AWSマネージドルール3種（CommonRuleSet / KnownBadInputs / AmazonIpReputationList）＋ レートベースルール（5分/2000req/IP）＋ CloudWatch Logs 出力。

## 前提

- **先に `cost-start` で production を起動しておく**。ALB が存在しない状態で `enable_waf = true` にすると association が失敗する。
- terraform ロール（`github-actions-terraform-prod`）に `wafv2:*` / `config:*` / `securityhub:*` が必要。`bootstrap-prod` に含めてあるので、権限追加後は `bootstrap-prod` を一度 apply しておくこと（nonprod で試す場合は `bootstrap-nonprod` も同様）。

## ON 手順

1. `cost-start` で production 起動（ALB / ECS / RDS）
2. 次の 3 ファイルのフラグを `true` に変更する PR を作成
   - `envs/prod/production/backend/main.tf` … `module "backend"` 呼び出しの `enable_waf`（変数経由なら `terraform.tfvars` か CI の `-var`）→ 実際は `envs/prod/production/backend/` の `enable_waf` を true に
   - `envs/prod/production/frontend/` の `enable_waf` → true
   - `envs/prod/production/security/main.tf` の `enable_security_hub` / `enable_config` → true
3. PR をマージ → `infra-ci.yml` が backend / frontend / security の 3 コンポーネントを apply
   - apply 自体は数分。CloudFront への Web ACL 紐付けは伝播に 5〜15 分
   - Config 有効化直後、既存リソースの初回記録（configuration item 課金 $0.003/件、production 規模で合計 $1〜2 程度）が走る
4. 反映確認
   - `aws wafv2 list-web-acls --scope REGIONAL --region ap-northeast-1`
   - `aws wafv2 list-web-acls --scope CLOUDFRONT --region us-east-1`
   - CloudFront ディストリビューションの `WebACLId` が設定されているか
   - `aws configservice describe-configuration-recorder-status --region ap-northeast-1`
   - `aws securityhub get-enabled-standards --region ap-northeast-1`
   - CloudFront 経由で会員登録→予約→キャンセルが WAF 誤検知でブロックされないこと（誤検知が出たら該当マネージドルールを一時 count モードに）

## OFF 手順

1. 上記 3 ファイルのフラグを `false` に戻す PR をマージ
2. `infra-ci.yml` の apply で以下が削除される
   - WAF Web ACL ×2、association、WAFログ用ロググループ
   - Security Hub account / 標準サブスクリプション
   - Config recorder / delivery channel / S3 バケット（`force_destroy = true`）/ IAM ロール
   - CloudFront の `web_acl_id` は `null` に戻る（distribution 更新、伝播あり）
3. `cost-stop` を通常どおり実行（ALB / ECS / RDS）

## コスト目安（ON の期間のみ）

| | 月額 |
|---|---|
| WAF（Web ACL ×2 ＋ マネージドルール各3 ＋ レートルール） | ~$16 |
| AWS Config | ~$2〜5 |
| Security Hub | ~$1〜3 |
| 初回記録バースト（Config、1回） | ~$1〜2 |
