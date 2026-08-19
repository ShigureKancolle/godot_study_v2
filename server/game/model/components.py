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

@dataclass
class FacingComponent(Component):
    facing: float = 0.0

