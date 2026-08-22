# coding=utf-8

from protocol import router
from transport.outbound_queue import OutBoundQueue
from transport.connection_registry import ConnectionContext, ConnectionRegistry
from game.commands import LoginCommand
from proto.generated import game_pb2

def login_handle(context: ConnectionContext, proto: game_pb2.LoginRequest):
    print(f"player login acc: {proto.account}")
    account = proto.account.strip()
    player_name = proto.player_name.strip()
    if not account:
        raise ValueError("account is required")

    ConnectionRegistry.get().bind_account(context.connection_id, account, player_name)

    accepted = game_pb2.LoginAccepted(
        account=account,
        player_name=player_name,
    )

    OutBoundQueue.get().send_to(context.connection_id, "login_accepted", accepted)
