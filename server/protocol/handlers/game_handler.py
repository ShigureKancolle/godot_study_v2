# coding = utf-8
from game import commands, world
from game.entity_projector import project_entity_snapshot
from transport.outbound_queue import OutBoundQueue
from transport.connection_registry import ConnectionContext, ConnectionRegistry
from proto.generated import game_pb2
import time
from game.events import EntityJoinedEvent, Event


def enter_game_request_handler(context: ConnectionContext, proto: game_pb2.EnterGameRequest):
    print("player enter game acc:", context.account_id)
    if not context.account_id:
        # 没有绑定账号
        print("player enter game without account")
        return []

    # 这是world的事件 通过command来让world通知客户端
    gw = world.get_room()  # 有多个room就要通过proto来获取了
    cmd = commands.JoinCommand(
        account=context.account_id,
        player_name=proto.player_name,
    )
    gw.enqueue_command(cmd)

def move_intent_handler(context: ConnectionContext, proto: game_pb2.MoveIntent):
    print("player move intent:", proto)
    gw = world.get_room()
    cmd = commands.MoveCommand(
        entity_id=context.player_entity_id,
        dir_x=proto.dir_x,
        dir_y=proto.dir_y,
        moving=proto.moving,
    )
    gw.enqueue_command(cmd)