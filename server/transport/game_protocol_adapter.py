# coding=utf-8
"""将领域事件和快照转换成服务端出站 Protobuf 消息。"""

import typing

from game.entity_projector import project_entity_snapshot
from transport.outbound_queue import OutBoundQueue
from transport.connection_registry import ConnectionRegistry
import game.events as events
import proto.generated.game_pb2 as game_pb2
if typing.TYPE_CHECKING:
    import game.world as world
    from typing import Callable
    

class GameProtocolAdapter:
    def __init__(self, world: "world.GameWorld"):
        self._game_world = world
        self._outbound = OutBoundQueue.get()
        self._connections = ConnectionRegistry.get()
        self._event_handlers: dict[type, Callable] = {}
        self._moved_entitys: list[game_pb2.MovementEntry] = []

    def register_event_handler(self, event_type: type, handler: "Callable"):
        self._event_handlers[event_type] = handler

    def publish_tick_result(self, tick_result: events.TickResult):
        self._moved_entitys = []
        server_tick = tick_result.server_tick
        for event in tick_result.events:
            event_type = type(event)
            if event_type in self._event_handlers:
                self._event_handlers[event_type](event, server_tick)

        if self._moved_entitys:
            msg = game_pb2.MovementFrame(
                server_tick=server_tick,
                entries=self._moved_entitys
            )
            self._outbound.broadcast(
                "movement_frame",
                msg,
                room_id=self._game_world.room_id,
                server_tick=server_tick,
            )
        
    def to_movement_entry(self, movement: events.EntityMovedEvent, server_tick: int) -> game_pb2.MovementEntry:
        movement_entry = game_pb2.MovementEntry(
            entity_id=movement.entity_id,
            x=movement.x,
            y=movement.y,
            moving=movement.moving,
            anim_state=movement.anim_state
        )

        self._moved_entitys.append(movement_entry)

    def publish_entity_removed(self, entity_leaved: events.EntityRemovedEvent, server_tick: int):
        # 通知其他玩家这个玩家离开了游戏
        entity_leaved = game_pb2.EntityRemoved(
            entity_id=entity_leaved.entity_id
        )
        self._outbound.broadcast(
            "entity_removed",
            entity_leaved,
            room_id=self._game_world.room_id,
            server_tick=server_tick,
        )

    def publish_command_rejected(self, rejected: events.CommandRejectedEvent, server_tick: int):
        message = game_pb2.CommandRejected(
            command_name=rejected.command_name,
            reason_code=rejected.reason_code,
            reason_message=rejected.reason_message,
        )
        self._outbound.send_to(
            rejected.connection_id,
            "command_rejected",
            message,
            server_tick=server_tick,
        )

    def publish_entity_joined(self, entity_joined: events.EntityJoinedEvent, server_tick: int):
        print(f"publish_entity_joined  server_tick: {server_tick}  account: {entity_joined.account}")
        # 获取连接
        context = self._connections.get_context_by_account_id(entity_joined.account)
        if not context:
            print(f"publish_entity_joined  not context  account: {entity_joined.account}")
            return

        # 刚进入的玩家需要游戏世界的快照
        snapshot = self._make_all_snapshot(server_tick, self._game_world.room_id, entity_joined.entity_info.entity_id)
        self._outbound.send_to(context.connection_id, "world_snapshot", snapshot, server_tick=server_tick)

        # 通知其他玩家这个玩家进入了游戏
        entity_spawned = game_pb2.EntitySpawned()
        entity_spawned.entity_id = entity_joined.entity_info.entity_id
        entity_spawned.entity_info.CopyFrom(self.make_entity_info_by_entity_snapshot(entity_joined.entity_info))

        context.room_id = self._game_world.room_id
        context.player_entity_id = entity_joined.entity_info.entity_id
        self._outbound.broadcast(
            "entity_spawned",
            entity_spawned,
            exclude_ids=[context.connection_id],
            room_id=context.room_id,
            server_tick=server_tick,
        )

    def _make_all_snapshot(self, server_tick: int, room_id: str, self_entity_id: str) -> game_pb2.WorldSnapshot:
        msg = game_pb2.WorldSnapshot()
        msg.room_id = room_id
        msg.server_tick = server_tick
        msg.map_id = "test_level"
        msg.self_entity_id = self_entity_id
        entity_infos = []
        for entity in self._game_world.get_entities():
            info_snapshot = project_entity_snapshot(entity)
            entity_info = self.make_entity_info_by_entity_snapshot(info_snapshot)
            entity_infos.append(entity_info)
        msg.entities.extend(entity_infos)
        return msg

    def make_entity_info_by_entity_snapshot(self, entity_snapshot: "world.EntitySnapshot") -> game_pb2.EntityInfo:
        entity_info = game_pb2.EntityInfo()
        entity_info.entity_id = entity_snapshot.entity_id
        entity_info.player_name = entity_snapshot.player_name
        entity_info.entity_type = entity_snapshot.entity_type
        entity_info.x = entity_snapshot.x
        entity_info.y = entity_snapshot.y
        entity_info.facing = entity_snapshot.facing
        entity_info.anim_state = entity_snapshot.anim_state
        entity_info.moving = entity_snapshot.moving
        entity_info.ai_state = entity_snapshot.ai_state
        return entity_info
