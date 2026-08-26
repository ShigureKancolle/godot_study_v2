# coding=utf-8
"""只负责将 LoginRequest 协议消息转换成会话命令。"""

from protocol.contract import validate_login_request
from transport.connection_registry import ConnectionContext
from game.commands import LoginCommand
from proto.generated import game_pb2

def login_handle(context: ConnectionContext, proto: game_pb2.LoginRequest):
    account, player_name = validate_login_request(proto)
    return LoginCommand(
        connection_id=context.connection_id,
        account=account,
        player_name=player_name,
    )
