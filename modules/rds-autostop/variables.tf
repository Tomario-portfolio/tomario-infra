variable "env" {
  description = "環境名（dev/staging/production）。RDSインスタンス識別子・ECSクラスター/サービス名を tomario-<env>-* 規則で組み立てる"
  type        = string
}
