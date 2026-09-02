# coding=utf-8
"""将领域事件和世界快照转换成服务端出站 Protobuf 消息。"""

import logging
import typing

import game.events as events
import proto.generated.game_pb2 as game_pb2
from game.entity_projector import project_entity_snapshot
from transport.connection_registry import ConnectionRegistry
from transport.game_proto_projector import GameProtoProjector
from transport.outbound_queue import OutBoundQueue
from transport.world_frame_build import WorldFrameBuilder

if typing.TYPE_CHECKING:
    import game.world as world


logger = logging.getLogger(__name__)


class GameProtocolAdapter:
    """按服务端 tick 聚合并发布权威世界消息。"""

    def __init__(self, world: "world.GameWorld"):
        self._game_world = world
        self._outbound = OutBoundQueue.get()
        self._connections = ConnectionRegistry.get()

    def publish_tick_result(self, tick_result: events.TickResult):
        """将一个 tick 的领域事件聚合成至多一个 WorldFrame。"""
        server_tick = tick_result.server_tick
        builder = WorldFrameBuilder(server_tick)
        excluded_connection_ids: set[int] = set()

        for current_event in tick_result.events:
            if isinstance(current_event, events.CommandRejectedEvent):
                self.publish_command_rejected(current_event, server_tick)
                continue

            if isinstance(current_event, events.EntityJoinedEvent):
                connection_id = self._send_join_snapshot(current_event, server_tick)
                if connection_id is not None:
                    excluded_connection_ids.add(connection_id)

            builder.apply(current_event)

        if not builder.has_changes():
            return

        self._outbound.broadcast(
            "world_frame",
            builder.build(),
            room_id=self._game_world.room_id,
            server_tick=server_tick,
            exclude_ids=list(excluded_connection_ids),
        )

    def publish_command_rejected(
        self,
        rejected: events.CommandRejectedEvent,
        server_tick: int,
    ):
        """向命令所属连接发送拒绝原因。"""
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

    def _send_join_snapshot(
        self,
        entity_joined: events.EntityJoinedEvent,
        server_tick: int,
    ) -> int | None:
        """向新加入的连接发送当前 tick 的完整世界快照。"""
        logger.debug(
            "实体加入发送世界快照：server_tick=%s, account=%s",
            server_tick,
            entity_joined.account,
        )
        context = self._connections.get_context_by_account_id(entity_joined.account)
        if not context:
            logger.warning(
                "实体加入发送世界快照时找不到连接：account=%s",
                entity_joined.account,
            )
            return None

        context.room_id = self._game_world.room_id
        context.player_entity_id = entity_joined.entity_info.entity_id
        snapshot = self._make_all_snapshot(
            server_tick,
            self._game_world.room_id,
            entity_joined.entity_info.entity_id,
        )
        self._outbound.send_to(
            context.connection_id,
            "world_snapshot",
            snapshot,
            server_tick=server_tick,
        )
        return context.connection_id

    def _make_all_snapshot(
        self,
        server_tick: int,
        room_id: str,
        self_entity_id: str,
    ) -> game_pb2.WorldSnapshot:
        """投影当前世界的完整权威快照。"""
        snapshot = game_pb2.WorldSnapshot(
            room_id=room_id,
            server_tick=server_tick,
            map_id="test_level",
            self_entity_id=self_entity_id,
        )
        snapshot.entities.extend(
            GameProtoProjector.entity_info(project_entity_snapshot(entity))
            for entity in self._game_world.get_entities()
        )
        return snapshot
