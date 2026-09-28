"""
RDS自動停止Lambda（REL-4 / COST-4 / SUS-3）

AWSはstopped状態のRDSインスタンスを最大7日で自動的に再起動(available化)する仕様がある。
このLambdaはEventBridgeで毎日1回起動し、RDSがavailableなのに対応するECSサービスが
稼働していない（＝cost-startされたわけではなく、7日制約による意図しない自動復旧の可能性が高い）
場合、RDSを再度停止してタイマーをリセットする。

正規のcost-start（RDS + ECS + ALBをまとめて起動）の場合はECSサービスもactiveになっているため、
誤って正規稼働中の環境を止めてしまうことはない。
"""
import os

import boto3

rds = boto3.client("rds")
ecs = boto3.client("ecs")


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

    print(f"{rds_id}: available but ECS not active - likely 7-day forced auto-restart, stopping again")
    rds.stop_db_instance(DBInstanceIdentifier=rds_id)
