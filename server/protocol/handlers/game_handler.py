# coding = utf-8
from game import world
from game.entity_projector import project_entity_snapshot
from transport.outbound_queue import OutBoundQueue
from transport.connection_registry import ConnectionContext, ConnectionRegistry
from proto.generated import game_pb2
import time
from game.events import EntityJoinedEvent, Event


def enter_game_request_handler(context: ConnectionContext, proto: game_pb2.LoginRequest) -> list[Event]:
    print("player enter game acc:", context.account_id)
    if not context.account_id:
        # 没有绑定账号
        print("player enter game without account")
        return []

    # TODO 看看房间是否存在 看看是否是创建房间 如果是创建房间， 就忽略房间id直接创建， 否则加入房间， 房间不存在则返回不存在提示
    if proto.create_room:
        # 创建房间



        world_snapshot = game_pb2.WorldSnapshot(
            room_id=proto.room_id,
            entities=[],
            timestamp=int(time.time()),
        )

        OutBoundQueue.get().send_to(context.connection_id, "world_snapshot", world_snapshot)

        return []
    else:
        # 加入房间
        room = world.get_room()
        player = room.create_player(context.account_id)
        player_info = project_entity_snapshot(player)
        event = EntityJoinedEvent(entity_id=player.entity_id, player_info=player_info)
        return [event]
