# coding=utf-8

from game.model.entity import Entity
from game.events import EntitySnapshot, CombatSnapshot
from game.model import components, combat_component
from typing import Any


def project_entity_snapshot(entity: Entity) -> EntitySnapshot:
    return EntitySnapshot(
        **project_identity_snapshot(entity),
        **project_transform_snapshots(entity),
        **project_movement_snapshots(entity),
        **project_ai_state_snapshot(entity),
        combat_snapshot=project_combat_snapshot(entity),
    )

def project_identity_snapshot(entity: Entity) -> dict[str, Any]:
    name = ""
    if player_component := entity.get_component(components.PlayerComponent):
        player_component: components.PlayerComponent
        name = player_component.player_name

    return {
        "entity_id": entity.entity_id,
        "player_name": name,
        "entity_type": entity.entity_type.value,
    }

def project_ai_state_snapshot(entity: Entity) -> dict[str, Any]:
    ai_state = ""
    # if ai_component := entity.get_component(components.AIComponent):
    #     ai_component: components.AIComponent
    #     ai_state = ai_component.state

    return {
        # "entity_id": entity.entity_id,
        "ai_state": ai_state,
    }

def project_transform_snapshots(entity: Entity) -> dict[str, Any]:
    transform_component: components.TransformComponent = entity.get_component(components.TransformComponent)
    if not transform_component:
        raise ValueError("entity must have TransformComponentComponent")

    res = {
        # "entity_id": entity.entity_id,
        "x": transform_component.x,
        "y": transform_component.y,
    }
    return res

def project_movement_snapshots(entity: Entity) -> dict[str, Any]:
    movement_component: components.MovementComponent = entity.get_component(components.MovementComponent)
    if not movement_component:
        return {}

    res = {
        # "entity_id": entity.entity_id,
        "moving": movement_component.moving,
        "anim_state": "move" if movement_component.moving else "idle",
        "facing": (movement_component.dir_x, movement_component.dir_y),
    }
    return res

def project_combat_snapshot(entity: Entity) -> CombatSnapshot:
    combat: combat_component.CombatComponent = entity.get_component(combat_component.CombatComponent)
    if not combat:
        return CombatSnapshot(entity_id=entity.entity_id)

    return CombatSnapshot(
        entity_id=entity.entity_id,
        atk_facing=combat.atk_facing,
        hp=combat.hp,
        max_hp=combat.max_hp,
        dead=combat.is_dead,
        defense=combat.defense,
        attack=combat.attack,
    )