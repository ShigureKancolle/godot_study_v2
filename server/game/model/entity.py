# coding=utf-8

import dataclasses
import typing
import enum
import game.model.components as comps


class EntityType(enum.Enum):
    PLAYER = 1
    ENEMY = 2

@dataclasses.dataclass
class EntityInfo:
    entity_id: str = ""
    entity_type: EntityType = EntityType.PLAYER

class Entity:
    def __init__(self, entity_info: EntityInfo):
        # 必须要有entity_info 其他的一些可以没有
        self._entity_info = entity_info
        self._components: dict[type, comps.Component] = {}

    @property
    def entity_info(self) -> EntityInfo:
        return self._entity_info

    def __repr__(self) -> str:
        transform_component = self.get_component(comps.TransformComponent)
        return f"Entity(entity_info={self._entity_info}, x={transform_component.x}, y={transform_component.y},)"

    def add_component(self, component: comps.Component):
        self._components[type(component)] = component

    def get_component(self, component_type: type) -> comps.Component | None:
        return self._components.get(component_type, None)

    def get_comp_types(self) -> list[type]:
        return list(self._components.keys())