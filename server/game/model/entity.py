# coding=utf-8

import dataclasses
import typing
import enum
import game.model.components as comps
import game.model.combat_component as combat_comp
import game.events as event


class EntityType(enum.Enum):
    PLAYER = 1
    ENEMY = 2
    ORNAMENT = 3 # 装饰品 不能被交互 只能用来看 比如一朵花

class Entity:
    def __init__(self, entity_id: str, entity_config_key: str):
        self._entity_id = entity_id
        self.entity_type: EntityType = EntityType.ORNAMENT
        self._components: dict[type, comps.Component] = {}
        self._entity_config_key = entity_config_key
        self.hit_box: combat_comp.HitBox = combat_comp.HitBox()

    @property
    def entity_id(self) -> str:
        return self._entity_id

    @property
    def entity_config_key(self) -> str:
        return self._entity_config_key

    def __repr__(self) -> str:
        transform_component = self.get_component(comps.TransformComponent)
        return f"Entity(entity_id={self._entity_id}, x={transform_component.x}, y={transform_component.y},)" 

    def add_component(self, component: comps.Component):
        self._components[type(component)] = component

    def get_component(self, component_type: type) -> comps.Component | None:
        return self._components.get(component_type, None)

    def get_comp_types(self) -> list[type]:
        return list(self._components.keys())
