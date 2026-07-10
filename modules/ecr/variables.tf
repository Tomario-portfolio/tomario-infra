variable "env" {
  description = "環境名（タグ付け用）"
  type        = string
}

variable "name" {
  description = "ECRリポジトリ名。既存リポジトリをstate mvで引き継ぐ場合、ECRはリネーム不可のため実際の名前をそのまま渡すこと"
  type        = string
}
