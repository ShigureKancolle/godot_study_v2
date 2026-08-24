# coding=utf-8

import typing

from game.entity_projector import project_entity_snapshot
from transport.outbound_queue import OutBoundQueue
from transport.connection_registry import ConnectionRegistry
if typing.TYPE_CHECKING:
    import game.world as world
    import game.events as events
    import proto.generated.game_pb2 as game_pb2

class GameProtocolAdapter:
    def __init__(self, world: world.GameWorld):
        self._game_world = world
        self._outbound = OutBoundQueue.get()
        self._connections = ConnectionRegistry.get()
        
    def publish_tick_result(self, tick_result: events.TickResult):
        moved_entitys = []
        server_tick = tick_result.server_tick
        for event in tick_result.events:
            if isinstance(event, events.EntityJoinedEvent):
                self._publish_entity_joined(event, server_tick)

            elif isinstance(event, events.EntityMovedEvent):
                moved_entitys.append(self._to_movement_entry(event))

    def _to_movement_entry(self, movement: events.EntityMovedEvent) -> game_pb2.MovementFrame:
        pass

    def _publish_entity_joined(self, entity_joined: events.EntityJoinedEvent, server_tick: int):
        # 获取连接
        context = self._connections.get_context_by_account_id(entity_joined.account)
        if not context:
            return

        # 刚进入的玩家需要游戏世界的快照
        snapshot = self._make_snapshot(server_tick)
        self._outbound.send_to(context.connection_id, "world_snapshot", snapshot, server_tick=server_tick)

        # 通知其他玩家这个玩家进入了游戏
        entity_spawned = game_pb2.EntitySpawned()
        entity_spawned.entity_id = entity_joined.entity_info.entity_id
        entity_spawned.entity_info = entity_joined.entity_info
        self._outbound.broadcast("entity_spawned", entity_spawned, exclude_ids=[context.connection_id], room_id=context.room_id)

    def _make_snapshot(self, server_tick: int, room_id: str) -> game_pb2.WorldSnapshot:
        msg = game_pb2.WorldSnapshot()
        msg.room_id = room_id
        msg.server_tick = server_tick
        entity_infos = []
        for entity in self._game_world.entities:
            entity_infos.append(project_entity_snapshot(entity))
        msg.entities.extend(entity_infos)
        return msg
