# coding=utf-8
"""将已认证连接的战斗协议请求转换成 WorldCommand。"""

from game import commands
from transport.connection_registry import ConnectionContext
from proto.generated import game_pb2
from protocol.contract import (
    validate_atk_rotate_intent,
)

def atk_rotate_intent_handler(context: ConnectionContext, proto: game_pb2.EnterGameRequest):
    atk_facing, entity_id = validate_atk_rotate_intent(proto)
    return commands.AtkRotateCommand(
        connection_id=context.connection_id,
        entity_id=entity_id,
        atk_facing=atk_facing,
    )
