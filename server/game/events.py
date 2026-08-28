# coding=utf-8
"""GameWorld 每个 tick 产生的不可变领域事件和只读快照。"""

from dataclasses import dataclass, field

@dataclass(frozen=True)
class CombatSnapshot:
    # hp: int = 100
    # max_hp: int = 100
    # attack: int = 10
    # defense: int = 10
    entity_id: str = ""
    atk_facing: float = 0.0

@dataclass(frozen=True)
class EntitySnapshot:
    entity_id: str = ""
    player_name: str = ""
    entity_type: int = 0
    x: float = 0.0
    y: float = 0.0
    facing: tuple[float, float] = field(default_factory=tuple)
    anim_state: str = ""
    moving: bool = False
    ai_state: str = ""
    combat_snapshot: CombatSnapshot = field(default_factory=CombatSnapshot)

class Event:
    pass

@dataclass(frozen=True)
class TickResult:
    server_tick: int = 1
    events: list = field(default_factory=list)

@dataclass(frozen=True)
class EntityMovedEvent(Event):
    entity_id: str = ""
    x: float = 0.0
    y: float = 0.0
    moving: bool = False
    anim_state: str = ""
    facing: tuple[float, float] = field(default_factory=tuple)

@dataclass(frozen=True)
class EntityJoinedEvent(Event):
    account: str = ""
    entity_info: EntitySnapshot = field(default_factory=EntitySnapshot)
    
@dataclass(frozen=True)
class EntityFacingEvent(Event):
    entity_id: str = ""
    facing: float = 0.0

@dataclass(frozen=True)
class EntityAttackStartEvent(Event):
    entity_id: str = ""
    attack_id: int = 0
    facing: float = 0.0

@dataclass(frozen=True)
class EntityAttackHitEvent(Event):
    entity_id: str = ""
    attack_id: int = 0
    hit_entity_ids: list[str] = field(default_factory=list)

@dataclass(frozen=True)
class EntityHurtEvent(Event):
    entity_id: str = ""
    damage: int = 0
    is_critical: bool = False

@dataclass(frozen=True)
class WorldSnapshot(Event):
    room_id: str = ""
    server_tick: int = 0
    entities: dict[str, EntitySnapshot] = field(default_factory=dict)

@dataclass(frozen=True)
class EntityRemovedEvent(Event):
    entity_id: str = ""
    account: str = ""

@dataclass(frozen=True)
class EntityAtkRotateEvent(Event):
    entity_id: str = ""
    atk_facing: float = 0.0

@dataclass(frozen=True)
class CommandRejectedEvent(Event):
    connection_id: int = 0
    command_name: str = ""
    reason_code: str = ""
    reason_message: str = ""
