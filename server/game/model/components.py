# coding=utf-8

from dataclasses import dataclass, field

@dataclass
class Component:
    pass

@dataclass
class TransformComponent(Component):
    x: float = 0.0
    y: float = 0.0

@dataclass
class MovementComponent(Component):
    speed: float = 0.0
    dir_x: float = 0.0
    dir_y: float = 0.0
    moving: bool = False
    input_changed: bool = False
    is_locked: bool = False

@dataclass
class FacingComponent(Component):
    _facing: tuple[float, float] = (0.0, 0.0)

    def __init__(self, facing: tuple[float, float] = (0.0, 0.0)):
        self._facing = facing

    @property
    def facing(self) -> tuple[float, float]:
        return self._facing

    @facing.setter
    def facing(self, value: tuple[float, float]):
        self._facing = value

@dataclass
class PlayerComponent(Component):
    account_id: str = ""
    player_name: str = ""

@dataclass
class CollisionComponent(Component):
    body_radius: float = 0.0


@dataclass
class DeathTimerComponent(Component):
    """记录实体死亡后等待移除的权威计时状态。"""
    elapsed_ms: float = 0.0
    remove_after_ms: int = 0
