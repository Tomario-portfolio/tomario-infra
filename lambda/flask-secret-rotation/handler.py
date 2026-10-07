"""
Flask SECRET_KEYのローテーションLambda（SEC-8）

Secrets Managerの自動ローテーションから呼ばれ、以下の4ステップで鍵を入れ替える。

- createSecret：新しいランダムな鍵を生成し、AWSPENDINGとして登録する
- setSecret：何もしない（DBのパスワードと違い、外部のシステムに鍵を反映する必要が無い）
- testSecret：AWSPENDINGの鍵が取得でき、十分な長さがあることを確認する
- finishSecret：AWSCURRENTをAWSPENDINGの版へ移す（元の鍵はAWSPREVIOUSになる）。
  ECSタスクはシークレットを起動時にしか読み込まないため、ECSサービスが稼働中なら
  タスクを入れ替えて新しい鍵を読み込ませる（cost-stop中でサービスが無い場合は何もしない）
"""
import os

import boto3

secretsmanager = boto3.client("secretsmanager")
ecs = boto3.client("ecs")

KEY_LENGTH = 50
MIN_KEY_LENGTH = 32


def handler(event, context):
    secret_arn = event["SecretId"]
    token = event["ClientRequestToken"]
    step = event["Step"]

    metadata = secretsmanager.describe_secret(SecretId=secret_arn)
    if not metadata.get("RotationEnabled"):
        raise ValueError(f"{secret_arn}: rotation is not enabled")

    versions = metadata["VersionIdsToStages"]
    if token not in versions:
        raise ValueError(f"{secret_arn}: version {token} has no stage for rotation")
    if "AWSCURRENT" in versions[token]:
        print(f"{secret_arn}: version {token} is already AWSCURRENT, nothing to do")
        return
    if "AWSPENDING" not in versions[token]:
        raise ValueError(f"{secret_arn}: version {token} is not AWSPENDING")

    if step == "createSecret":
        create_secret(secret_arn, token)
    elif step == "setSecret":
        print(f"{secret_arn}: setSecret - nothing to set")
    elif step == "testSecret":
        test_secret(secret_arn, token)
    elif step == "finishSecret":
        finish_secret(secret_arn, token, versions)
        redeploy_ecs_service()
    else:
        raise ValueError(f"unknown step: {step}")


def create_secret(secret_arn, token):
    # リトライで再度呼ばれた場合に、既に作成済みのAWSPENDINGを上書きしない
    try:
        secretsmanager.get_secret_value(SecretId=secret_arn, VersionId=token, VersionStage="AWSPENDING")
        print(f"{secret_arn}: AWSPENDING already exists for {token}")
        return
    except secretsmanager.exceptions.ResourceNotFoundException:
        pass

    new_key = secretsmanager.get_random_password(PasswordLength=KEY_LENGTH)["RandomPassword"]
    secretsmanager.put_secret_value(
        SecretId=secret_arn,
        ClientRequestToken=token,
        SecretString=new_key,
        VersionStages=["AWSPENDING"],
    )
    print(f"{secret_arn}: created new key as AWSPENDING ({token})")


def test_secret(secret_arn, token):
    value = secretsmanager.get_secret_value(SecretId=secret_arn, VersionId=token, VersionStage="AWSPENDING")["SecretString"]
    if len(value) < MIN_KEY_LENGTH:
        raise ValueError(f"{secret_arn}: AWSPENDING key is too short ({len(value)} chars)")
    print(f"{secret_arn}: AWSPENDING key looks valid")


def finish_secret(secret_arn, token, versions):
    current_version = next((v for v, stages in versions.items() if "AWSCURRENT" in stages), None)
    secretsmanager.update_secret_version_stage(
        SecretId=secret_arn,
        VersionStage="AWSCURRENT",
        MoveToVersionId=token,
        RemoveFromVersionId=current_version,
    )
    print(f"{secret_arn}: moved AWSCURRENT from {current_version} to {token}")


def redeploy_ecs_service():
    cluster = os.environ["ECS_CLUSTER"]
    service = os.environ["ECS_SERVICE"]

    services = ecs.describe_services(cluster=cluster, services=[service]).get("services", [])
    if not services or services[0]["status"] != "ACTIVE" or services[0]["desiredCount"] == 0:
        print(f"{cluster}/{service}: not running (cost-stop), skipping redeploy - new key is loaded at next cost-start")
        return

    ecs.update_service(cluster=cluster, service=service, forceNewDeployment=True)
    print(f"{cluster}/{service}: forced new deployment to load the new key")
