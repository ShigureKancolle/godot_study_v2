# coding=utf-8
"""世界帧构建器。"""
import proto.generated.game_pb2 as game_pb2
import logging
from typing import Callable
from transport.game_proto_projector import GameProtoProjector
import game.events as events
logger = logging.getLogger(__name__)

EventHandlerType = Callable[[events.Event], None]

class WorldFrameBuilder:
    def __init__(self, server_tick: int):
        self.server_tick = server_tick

        self.movements: dict[str, game_pb2.MovementEntry] = {}
        self.aims: dict[str, game_pb2.AimStateDelta] = {}
        self.health_states: dict[str, game_pb2.HealthStateDelta] = {}

        self.spawned_entities: dict[str, game_pb2.EntityInfo] = {}
        self.removed_entities: set[str] = set()

        self.events: list[game_pb2.WorldEvent] = []
        self.event_handlers: dict[events.Event, Callable] = {}
        self.register_event_handler()

    def register_event_handler(self):
        self.event_handlers = {
            events.EntityMovedEvent: self._event_handler_entity_moved_event,
            events.EntityJoinedEvent: self._event_handler_entity_joined_event,
            events.EntityAttackStartEvent: self._event_handler_entity_attack_start_event,
            events.EntityHurtEvent: self._event_handler_entity_hurt_event,
            events.EntityRemovedEvent: self._event_handler_entity_removed_event,
            events.EntityHealthChangedEvent: self._event_handler_entity_health_changed_event,
            events.EntityAtkRotateEvent: self._event_handler_entity_atk_rotate_event,
            events.EntitySpawnedEvent: self._event_handler_entity_joined_event,
            events.EntityAttackHitEvent: self._event_handler_entity_attack_hit_event,
        }


    def apply(self, event: events.Event):
        handler = self.event_handlers.get(type(event))
        if handler:
            handler(event)
            return True
        else:
            return False

    def has_changes(self) -> bool:
        return (
            bool(self.movements) or
            bool(self.aims) or
            bool(self.health_states) or
            bool(self.spawned_entities) or
            bool(self.removed_entities) or
            bool(self.events)
        )


    def build(self) -> game_pb2.WorldFrame:
        world_frame = game_pb2.WorldFrame()
        world_frame.movements.extend(self.movements.values())
        world_frame.aims.extend(self.aims.values())
        world_frame.health_states.extend(self.health_states.values())
        world_frame.spawned_entities.extend(self.spawned_entities.values())
        world_frame.removed_entity_ids.extend(self.removed_entities)
        world_frame.events.extend(self.events)
        return world_frame


    def _event_handler_entity_moved_event(self, event: events.EntityMovedEvent):
        movement_entry = GameProtoProjector.movement(event)

        self.movements[event.entity_id] = movement_entry

    def _event_handler_entity_joined_event(self, event: events.EntityJoinedEvent | events.EntitySpawnedEvent):
        self.spawned_entities[event.entity_info.entity_id] = GameProtoProjector.entity_info(event.entity_info)

    def _event_handler_entity_attack_start_event(self, event: events.EntityAttackStartEvent):
        self.events.append(GameProtoProjector.attack_start(event))

    def _event_handler_entity_hurt_event(self, event: events.EntityHurtEvent):
        self.events.append(GameProtoProjector.damage_event(event))

    def _event_handler_entity_removed_event(self, event: events.EntityRemovedEvent):
        self.removed_entities.add(event.entity_id)

    def _event_handler_entity_health_changed_event(self, event: events.EntityHealthChangedEvent):
        self.health_states[event.entity_id] = GameProtoProjector.health_state(event)

    def _event_handler_entity_atk_rotate_event(self, event: events.EntityAtkRotateEvent):
        self.aims[event.entity_id] = GameProtoProjector.aim_state(event)

    def _event_handler_entity_attack_hit_event(self, event: events.EntityAttackHitEvent):
        self.events.append(GameProtoProjector.attack_hit(event))










