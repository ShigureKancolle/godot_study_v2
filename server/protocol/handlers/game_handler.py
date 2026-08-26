# coding=utf-8
"""将已认证连接的游戏协议请求转换成 WorldCommand。"""

from game import commands
from protocol.contract import validate_enter_game_request, validate_move_intent
from transport.connection_registry import ConnectionContext
from proto.generated import game_pb2


def enter_game_request_handler(context: ConnectionContext, proto: game_pb2.EnterGameRequest):
    player_name = validate_enter_game_request(proto)
    return commands.JoinCommand(
        connection_id=context.connection_id,
        account=context.account_id,
        player_name=player_name,
    )

def move_intent_handler(context: ConnectionContext, proto: game_pb2.MoveIntent):
    validate_move_intent(proto)
    return commands.MoveCommand(
        connection_id=context.connection_id,
        entity_id=context.player_entity_id,
        dir_x=proto.dir_x,
        dir_y=proto.dir_y,
        moving=proto.moving,
    )
