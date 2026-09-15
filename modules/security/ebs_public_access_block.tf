# Security Hub finding「Block public access settings should be enabled for
# Amazon EBS snapshots」対応。EBSスナップショット自体は使用していないが、
# 将来誰かが手動でEBS/EC2を使いスナップショットを作った際に誤って
# パブリック共有されないよう、アカウントレベルの保険をかけておく。
resource "aws_ebs_snapshot_block_public_access" "this" {
  state = "block-all-sharing"
}
