# coding=utf-8

from dataclasses import dataclass, field

import typing
if typing.TYPE_CHECKING:
    from game.model.entity import Entity



@dataclass
class Component:
    def on_add_to_entity(self, entity: "Entity"):
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

@dataclass
class ExpComponent(Component):
    '''这个实体是经验实体，记录了实体的经验, system会把经验实体吸附到附近玩家上, 玩家会获得经验'''
    exp: int = 0
    target_id: str = ""

@dataclass
class PickupComponent(Component):
    '''拾取功能， '''
    pickup_radius_px: float = 0.0
    
