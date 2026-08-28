# coding=utf-8
"""将领域事件和快照转换成服务端出站 Protobuf 消息。"""

import typing
import logging

from game.entity_projector import project_entity_snapshot
from transport.outbound_queue import OutBoundQueue
from transport.connection_registry import ConnectionRegistry
import game.events as events
import proto.generated.game_pb2 as game_pb2
if typing.TYPE_CHECKING:
    import game.world as world
    from typing import Callable


logger = logging.getLogger(__name__)

class GameProtocolAdapter:
    def __init__(self, world: "world.GameWorld"):
        self._game_world = world
        self._outbound = OutBoundQueue.get()
        self._connections = ConnectionRegistry.get()
        self._event_handlers: dict[type, Callable] = {}
        self._moved_entitys: list[game_pb2.MovementEntry] = []
        self._moved_entitys = []
        self._combat_entitys: dict[str, game_pb2.CombatEntry]  = {}

    def register_event_handler(self, event_type: type, handler: "Callable"):
        self._event_handlers[event_type] = handler

    def publish_tick_result(self, tick_result: events.TickResult):
        self._moved_entitys = []
        self._combat_entitys = {}
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

        if self._combat_entitys:
            msg = game_pb2.CombatFrame(
                server_tick=server_tick,
                combats=self._combat_entitys.values()
            )
            self._outbound.broadcast(
                "combat_frame",
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
            anim_state=movement.anim_state,
            facing_x=movement.facing[0],
            facing_y=movement.facing[1],
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
        logger.debug("发布实体加入事件：server_tick=%s, account=%s", server_tick, entity_joined.account)
        # 获取连接
        context = self._connections.get_context_by_account_id(entity_joined.account)
        if not context:
            logger.warning("发布实体加入事件时找不到连接：account=%s", entity_joined.account)
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

    def make_entity_info_by_entity_snapshot(self, entity_snapshot: "events.EntitySnapshot") -> game_pb2.EntityInfo:
        entity_info = game_pb2.EntityInfo()
        entity_info.entity_id = entity_snapshot.entity_id
        entity_info.player_name = entity_snapshot.player_name
        entity_info.entity_type = entity_snapshot.entity_type
        entity_info.x = entity_snapshot.x
        entity_info.y = entity_snapshot.y
        entity_info.facing_x = entity_snapshot.facing[0]
        entity_info.facing_y = entity_snapshot.facing[1]
        entity_info.anim_state = entity_snapshot.anim_state
        entity_info.moving = entity_snapshot.moving
        entity_info.ai_state = entity_snapshot.ai_state

        # 战斗组件
        combat_entity_info = game_pb2.CombatEntityInfo(
            entity_id=entity_snapshot.entity_id,
            atk_facing=entity_snapshot.combat_snapshot.atk_facing,
        )
        
        entity_info.combat_entity_info.CopyFrom(combat_entity_info)
        return entity_info

    def publish_entity_attack_start(self, entity_attack_start: events.EntityAttackStartEvent, server_tick: int):
        # 玩家攻击才走这个方法
        logger.debug(
            "发布攻击开始事件：server_tick=%s, attacker_id=%s, attack_id=%s",
            server_tick,
            entity_attack_start.entity_id,
            entity_attack_start.attack_id,
        )
        msg = game_pb2.AttackStart(
            attacker_id=entity_attack_start.entity_id,
            attack_id=entity_attack_start.attack_id,
            atk_facing=entity_attack_start.atk_facing,
        )
        self._outbound.broadcast(
            "attack_start",
            msg,
            room_id=self._game_world.room_id,
            server_tick=server_tick,
        )

    def publish_entity_attack_hit(self, entity_attack_hit: events.EntityAttackHitEvent, server_tick: int):
        pass

    def publish_entity_hurt(self, entity_hurt: events.EntityHurtEvent, server_tick: int):
        pass

    def to_combat_atk_rotate_entry(self, entity_atk_rotate: events.EntityAtkRotateEvent, server_tick: int):
        entry = self._combat_entitys.get(entity_atk_rotate.entity_id, None)
        if not entry:
            entry = game_pb2.CombatEntityInfo()
            entry.entity_id = entity_atk_rotate.entity_id
            self._combat_entitys[entity_atk_rotate.entity_id] = entry
        entry.atk_facing = entity_atk_rotate.atk_facing
