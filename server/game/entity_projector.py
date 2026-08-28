# coding=utf-8

from game.model.entity import Entity
from game.events import EntitySnapshot, CombatSnapshot
from game.model import components, combat_component


def project_entity_snapshot(entity: Entity) -> EntitySnapshot:
    name = ""
    x = 0.0
    y = 0.0
    facing = (0, 0)
    moving = False
    ai_state = ""
    atk_facing = 0.0
    if player_component := entity.get_component(components.PlayerComponent):
        player_component: components.PlayerComponent
        name = player_component.player_name

    if transform_component := entity.get_component(components.TransformComponent):
        transform_component: components.TransformComponent
        x = transform_component.x
        y = transform_component.y

    if _combat_component := entity.get_component(combat_component.CombatComponent):
        _combat_component: combat_component.CombatComponent
        atk_facing = _combat_component.atk_facing

    if facing_component := entity.get_component(components.FacingComponent):
        facing_component: components.FacingComponent
        facing = facing_component.facing

    if movement_component := entity.get_component(components.MovementComponent):
        movement_component: components.MovementComponent
        moving = movement_component.moving

    combat_snapshot = CombatSnapshot(entity_id=entity.entity_id, atk_facing=atk_facing)

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
        combat_snapshot=combat_snapshot,
    )