# coding=utf-8

from game.model.entity import Entity
from game.events import EntitySnapshot
from game.model import components


def project_entity_snapshot(entity: Entity) -> EntitySnapshot:
    name, x, y, facing, anim_state, moving, ai_state = "", 0, 0, 0, "", False, ""
    if player_component := entity.get_component(components.PlayerComponent):
        player_component: components.PlayerComponent
        name = player_component.player_name

    if transform_component := entity.get_component(components.TransformComponent):
        transform_component: components.TransformComponent
        x = transform_component.x
        y = transform_component.y

    if combat_component := entity.get_component(components.CombatComponent):
        combat_component: components.CombatComponent

    if facing_component := entity.get_component(components.FacingComponent):
        facing_component: components.FacingComponent
        facing = facing_component.facing

    if movement_component := entity.get_component(components.MovementComponent):
        movement_component: components.MovementComponent
        moving = movement_component.moving

    return EntitySnapshot(
        entity_id=entity.entity_id,
        player_name=name,
        entity_type=entity.entity_type.value,
        x=x,
        y=y,
        facing=facing,
        anim_state="move" if moving else "idle",
        moving=moving,
        ai_state=ai_state,
    )