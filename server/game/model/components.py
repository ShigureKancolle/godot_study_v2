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
class CombatComponent(Component):
    hp: int = 100
    max_hp: int = 100
    attack: int = 0
    defense: int = 0
    is_dead: bool = False

@dataclass
class CollisionComponent(Component):
    body_radius: float = 0.0
