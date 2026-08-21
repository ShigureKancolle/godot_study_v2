# coding=utf-8

from dataclasses import dataclass, field
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

@dataclass(frozen=True)
class EntityJoinedEvent(Event):
    entity_id: str = ""
    account: str = ""
    x: float = 0.0
    y: float = 0.0

@dataclass(frozen=True)
class EntityFacingEvent(Event):
    entity_id: str = ""
    facing: float = 0.0

@dataclass(frozen=True)
class EntityAttackEvent(Event):
    entity_id: str = ""
    attack_id: int = 0