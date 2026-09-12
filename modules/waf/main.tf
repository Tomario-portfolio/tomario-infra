locals {
  name = "tomario-${var.env}-${var.name_suffix}"

  # アタッチするAWSマネージドルールグループ。
  # 課金上は1グループ＝1ルール（$1/月）扱い。中に含まれる個別ルール数は課金に影響しない。
  managed_rule_groups = [
    "AWSManagedRulesCommonRuleSet",          # OWASP相当のコアルール
    "AWSManagedRulesKnownBadInputsRuleSet",  # 既知の攻撃パターン（LFI/RFI・パストラバーサル等）
    "AWSManagedRulesAmazonIpReputationList", # Amazonが把握している不審IP
  ]
}

resource "aws_wafv2_web_acl" "this" {
  name        = local.name
  description = "tomario ${var.env} ${var.name_suffix} Web ACL"
  scope       = var.scope

  # マッチしなかったリクエストは通す（ブロックはルールで明示的に行う）
  default_action {
    allow {}
  }

  # AWSマネージドルールグループ（priority 1〜）。グループ側の判定に従う（override_action = none）
  dynamic "rule" {
    for_each = { for idx, group in local.managed_rule_groups : group => idx }

    content {
      name     = rule.key
      priority = rule.value + 1

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = rule.key
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.key
        sampled_requests_enabled   = true
      }
    }
  }

  # レートベースルール（DoS・ブルートフォース対策）。マネージドグループの後ろに置く
  rule {
    name     = "rate-limit"
    priority = length(local.managed_rule_groups) + 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = local.name
    sampled_requests_enabled   = true
  }

  tags = {
    Name = local.name
  }
}
