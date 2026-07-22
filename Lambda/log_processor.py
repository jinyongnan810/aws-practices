import base64
import gzip
import json
import os
from datetime import datetime, timezone

import boto3

BUCKET_NAME = os.environ["BUCKET_NAME"]
PREFIX = os.environ.get("PREFIX", "logs/")

s3 = boto3.client("s3")


def handler(event, context):
    """Receive a CloudWatch Logs subscription event and store it in S3.

    The subscription payload is base64-encoded, gzip-compressed JSON.
    """
    compressed = base64.b64decode(event["awslogs"]["data"])
    payload = json.loads(gzip.decompress(compressed))

    # Control messages are sent when a subscription is first created; skip them.
    if payload.get("messageType") == "CONTROL_MESSAGE":
        return

    now = datetime.now(timezone.utc)
    key = (
        f"{PREFIX}{payload['logGroup']}/{now:%Y/%m/%d}/"
        f"{payload['logStream']}-{now:%H%M%S%f}.json"
    )

    s3.put_object(
        Bucket=BUCKET_NAME,
        Key=key,
        Body=json.dumps(payload).encode("utf-8"),
    )
