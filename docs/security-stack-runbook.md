# セキュリティスタック ON/OFF 手順（production）

**WAF（CloudFront用・ALB用）+ AWS Config + Security Hub** を、必要な期間だけまとめて有効化する。
`cost-stop.yml` / `cost-start.yml` の日次サイクルとは**独立**。

- Security Hub は無効化の 90 日後に findings が削除される
- AWS Config は連続した構成履歴が価値なので、日次で止めると意味が薄れる

## 仕組み

| 要素 | 役割 |
|---|---|
| `enable_security_stack`（bool 変数） | prod の `security` / `backend` / `frontend` コンポーネントが宣言。true で各リソースを作成 |
| リポジトリ変数 `SECURITY_STACK_ENABLED` | 現在の状態を保存する唯一の場所。`security-stack.yml` が書き換える |
| `.github/workflows/security-stack.yml` | ワンクリック ON/OFF（`workflow_dispatch`、入力 `enable` / `disable`）。**実行前に prod を cost-start しておくこと**（ALB 実在チェックあり、無ければ即失敗） |
| `infra-ci.yml` / `cost-start.yml` / `cost-stop.yml` の `TF_VAR_enable_security_stack` | どの apply でも `SECURITY_STACK_ENABLED` を参照 → フラグが false に戻ってスタックが消えるのを防ぐ |

有効時に作られるもの（`modules/waf`: AWSマネージドルール3種〈CommonRuleSet / KnownBadInputs / AmazonIpReputationList〉＋ レートベースルール〈5分/2000req/IP〉＋ CloudWatch Logs 出力）:

| コンポーネント | リソース |
|---|---|
| `security` | AWS Config recorder + S3 + IAM、Security Hub + CIS v1.4.0 標準 |
| `frontend` | CloudFront用 Web ACL（us-east-1）→ distribution の `web_acl_id` |
| `backend` | ALB用 Web ACL + ALB への association |

## cost-start / cost-stop との関係

- **有効化・無効化は prod 起動中に行う**（`security-stack.yml` が ALB 実在をチェックして弾く）
- ON のまま `cost-stop` → ALB は `-target` destroy で消え、AWS 側で WAF association も自動解除。WAF Web ACL 本体は state に残る
- ON のまま `cost-start` → backend の full apply で ALB と association が一緒に再作成される（`cost-start.yml` が `SECURITY_STACK_ENABLED` を渡すため）
- `security-stack.yml` と `cost-start.yml` / `cost-stop.yml` を**同時に走らせない**（`production/backend` の state ロックが衝突する）

## 一度だけの準備

1. **`bootstrap-prod` を apply**
   terraform ロール（`github-actions-terraform-prod`）に `config:*` / `securityhub:*` を追加済み（PR #72）。未 apply だと `security` の apply が AccessDenied になる。
2. **fine-grained PAT を作成し `GH_PAT_VARIABLES` シークレットに登録**
   `GITHUB_TOKEN` では Actions 変数を更新できないため。権限は当該リポジトリの **Variables: Read and write** のみ。
3. **リポジトリ変数 `SECURITY_STACK_ENABLED` を作成**（初期値 `false`）
   Settings → Secrets and variables → Actions → Variables。

## ON 手順（ワンクリック）

1. **先に `cost-start`（account_group=prod, env=production）で production を起動しておく**
2. Actions → **Security Stack Toggle** → Run workflow → `action = enable`
3. `apply` ジョブが **prod Environment の承認待ち**で停止 → 承認
4. apply（`security` → `backend` → `frontend` の順）が走り、成功後に `SECURITY_STACK_ENABLED = true` が保存される
   - CloudFront への Web ACL 紐付けは伝播に 5〜15 分
   - Config 有効化直後、既存リソースの初回記録（configuration item 課金 $0.003/件、production 規模で合計 $1〜2 程度）
5. 確認
   ```
   aws wafv2 list-web-acls --scope REGIONAL  --region ap-northeast-1 --profile tomario-prod
   aws wafv2 list-web-acls --scope CLOUDFRONT --region us-east-1     --profile tomario-prod
   aws configservice describe-configuration-recorder-status --region ap-northeast-1 --profile tomario-prod
   aws securityhub get-enabled-standards --region ap-northeast-1 --profile tomario-prod
   ```
   CloudFront 経由で会員登録→予約→キャンセルが WAF 誤検知でブロックされないこと（誤検知が出たら該当マネージドルールを一時 `count` に）

## OFF 手順（ワンクリック）

1. **prod が cost-start 済みであること**（disable も backend/frontend の apply を伴うため）
2. Actions → **Security Stack Toggle** → Run workflow → `action = disable`
3. 承認 → apply で以下が削除される
   - WAF Web ACL ×2、association、WAFログ用ロググループ
   - Security Hub account / 標準サブスクリプション
   - Config recorder / delivery channel / S3 バケット（`force_destroy = true`）/ IAM ロール
   - CloudFront の `web_acl_id` は `null` に戻る（distribution 更新、伝播あり）
4. 成功後に `SECURITY_STACK_ENABLED = false` が保存される

## コスト目安（ON の期間のみ）

| | 月額 |
|---|---|
| WAF（Web ACL ×2 ＋ マネージドルール各3 ＋ レートルール） | ~$16 |
| AWS Config | ~$2〜5 |
| Security Hub | ~$1〜3 |
| 初回記録バースト（Config、1回） | ~$1〜2 |
