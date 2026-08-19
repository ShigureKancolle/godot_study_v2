# coding=utf-8

import dataclasses
class Event:
    pass

@dataclasses.dataclass
class EntityMovedEvent(Event):
    entity_id: str = ""
    x: float = 0.0
    y: float = 0.0
    moving: bool = False