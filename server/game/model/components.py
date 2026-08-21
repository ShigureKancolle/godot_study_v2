# coding=utf-8

from dataclasses import dataclass, field

@dataclass(frozen=True)
class Component:
    pass

@dataclass(frozen=True)
class TransformComponent(Component):
    x: float = 0.0
    y: float = 0.0

@dataclass(frozen=True)
class MovementComponent(Component):
    speed: float = 0.0
    dir_x: float = 0.0
    dir_y: float = 0.0
    moving: bool = False
    input_changed: bool = False
    is_locked: bool = False

@dataclass(frozen=True)
class FacingComponent(Component):
    facing: float = 0.0

@dataclass(frozen=True)
class PlayerComponent(Component):
    account_id: str = ""
    player_name: str = ""

@dataclass(frozen=True)
class CombatComponent(Component):
    hp: int = 100
    max_hp: int = 100
    attack: int = 0
    defense: int = 0
    is_dead: bool = False

@dataclass(frozen=True)
class CollisionComponent(Component):
    body_radius: float = 0.0
