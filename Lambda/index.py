import logging
import os

import boto3

TABLE_NAME = os.environ.get("TABLE_NAME", "UserSessions")

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def read_session(session_id):
    """Read a single session item by its SessionId."""
    result = table.get_item(Key={"SessionId": session_id})
    return result.get("Item")


def write_session(item):
    """Write (create or overwrite) a session item."""
    table.put_item(Item=item)
    return item


def handler(event, context):
    """Read from or write to the DynamoDB table based on the event's action.

    Expected event shapes:
      Read:  {"action": "read", "SessionId": "abc123"}
      Write: {"action": "write", "item": {"SessionId": "abc123", ...}}
    """
    action = event.get("action")

    if action == "read":
        logger.info(f"Reading session with SessionId: {event.get('SessionId')}")
        return {"item": read_session(event["SessionId"])}

    if action == "write":
        logger.info(f"Writing session item: {event.get('item')}")
        return {"item": write_session(event["item"])}

    raise ValueError(f"Unsupported action: {action!r}")
