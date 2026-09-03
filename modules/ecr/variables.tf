variable "env" {
  description = "環境名（タグ付け用）"
  type        = string
}

variable "name" {
  description = "ECRリポジトリ名。既存リポジトリをstate mvで引き継ぐ場合、ECRはリネーム不可のため実際の名前をそのまま渡すこと"
  type        = string
}

variable "cross_account_pull_role_arns" {
  description = "このリポジトリをpull専用でクロスアカウント参照させるIAMロールARNのリスト（productionへのpromoteフロー用）。ランタイム(ECSタスク)向けの共有ではなく、CI/CDジョブが一度だけdocker pullするためだけの最小権限"
  type        = list(string)
  default     = []
}
