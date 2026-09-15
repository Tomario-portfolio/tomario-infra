# Security Hub finding「SSM documents should have the block public sharing
# setting enabled」対応。SSM Documents自体は未使用だが、EBSスナップショットの
# 保険と同じ考え方で、アカウントレベルのpublic sharingブロックを有効化しておく。
resource "aws_ssm_service_setting" "document_public_sharing" {
  setting_id    = "/ssm/documents/console/public-sharing-permission"
  setting_value = "Disable"
}
