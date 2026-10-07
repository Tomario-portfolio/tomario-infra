"""
RDS自動停止Lambda（REL-4 / COST-4 / SUS-3）

AWSはstopped状態のRDSインスタンスを最大7日で自動的に再起動(available化)する仕様がある。
このLambdaはEventBridgeで1時間ごとに起動し、以下をすべて満たす場合にRDSを再度停止してタイマーをリセットする。

- RDSがavailable
- 直近FORCED_START_LOOKBACK_MINUTES以内に、7日制約による自動起動のRDSイベントが記録されている
- 対応するECSサービスが稼働していない

自動起動のイベントを条件に加えているのは、cost-startの途中（RDSは起動済みだがECSのdesiredCountを戻す前）に
実行された場合に、正規の起動を誤って止めないため。cost-startや手動の起動では自動起動のイベントは記録されない。
"""
import os

import boto3

rds = boto3.client("rds")
ecs = boto3.client("ecs")

# 7日制約による自動起動時にRDSが記録するイベントメッセージの一部
FORCED_START_MESSAGE = "exceeding the maximum allowed time being stopped"
# 1時間ごとの実行で取りこぼさないよう、実行間隔より長めに遡る
FORCED_START_LOOKBACK_MINUTES = 180


def forced_start_recorded(rds_id):
    resp = rds.describe_events(
        SourceIdentifier=rds_id,
        SourceType="db-instance",
        Duration=FORCED_START_LOOKBACK_MINUTES,
    )
    return any(FORCED_START_MESSAGE in e.get("Message", "") for e in resp.get("Events", []))


def handler(event, context):
    rds_id = os.environ["RDS_IDENTIFIER"]
    ecs_cluster = os.environ["ECS_CLUSTER"]
    ecs_service = os.environ["ECS_SERVICE"]

    try:
        resp = rds.describe_db_instances(DBInstanceIdentifier=rds_id)
    except rds.exceptions.DBInstanceNotFoundFault:
        print(f"{rds_id}: not found, skipping")
        return

    status = resp["DBInstances"][0]["DBInstanceStatus"]
    if status != "available":
        print(f"{rds_id}: status={status}, nothing to do")
        return

    if not forced_start_recorded(rds_id):
        print(f"{rds_id}: available but no 7-day forced auto-restart event - started by cost-start or manually, leaving as is")
        return

    ecs_active = False
    try:
        ecs_resp = ecs.describe_services(cluster=ecs_cluster, services=[ecs_service])
        services = ecs_resp.get("services", [])
        if services and services[0]["status"] == "ACTIVE" and services[0]["desiredCount"] > 0:
            ecs_active = True
    except Exception as e:
        print(f"{ecs_cluster}/{ecs_service}: describe_services failed ({e}), treating as inactive")

    if ecs_active:
        print(f"{rds_id}: available and ECS active - legitimate cost-start, leaving as is")
        return

    print(f"{rds_id}: 7-day forced auto-restart detected and ECS not active, stopping again")
    rds.stop_db_instance(DBInstanceIdentifier=rds_id)
