# coding=utf-8

from game.model.entity import Entity
from game.events import EntitySnapshot, CombatSnapshot, ProgressionSnapshot, MovePathSnapshot
from game.model import components, combat_component, progression_component, navigation_component, config_loader
from typing import Any

DEBUG = config_loader.get_constant("DEBUG_MSG_ENABLED")


def project_entity_snapshot(entity: Entity) -> EntitySnapshot:
    return EntitySnapshot(
        **project_identity_snapshot(entity),
        **project_transform_snapshots(entity),
        **project_movement_snapshots(entity),
        **project_ai_state_snapshot(entity),
        combat_snapshot=project_combat_snapshot(entity),
        progression_snapshot=project_progression_snapshot(entity),
        move_path_snapshot=project_move_path_snapshot(entity),
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
        "entity_config_key": entity.entity_config_key,
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
        "anim_state": "run" if movement_component.moving else "idle",
        "facing": (movement_component.dir_x, movement_component.dir_y),
    }
    return res

def project_combat_snapshot(entity: Entity) -> CombatSnapshot | None:
    combat: combat_component.CombatComponent = entity.get_component(combat_component.CombatComponent)
    if not combat:
        return None

    return CombatSnapshot(
        entity_id=entity.entity_id,
        atk_facing=combat.atk_facing,
        hp=combat.hp,
        max_hp=combat.max_hp,
        dead=combat.is_dead,
        defense=combat.defense,
        attack=combat.attack,
    )

def project_progression_snapshot(entity: Entity) -> ProgressionSnapshot | None:
    prog_comp: progression_component.ProgressionComponent = entity.get_component(progression_component.ProgressionComponent)
    if not prog_comp:
        return None

    return ProgressionSnapshot(
        entity_id=entity.entity_id,
        level=prog_comp.level,
        total_exp=prog_comp.total_exp,
    )

def project_move_path_snapshot(entity: Entity) -> MovePathSnapshot | None:
    if not DEBUG:
        return None

    navigation_comp: navigation_component.NavigationComponent = entity.get_component(navigation_component.NavigationComponent)
    if not navigation_comp:
        return None

    return MovePathSnapshot(
        entity_id=entity.entity_id,
        path=list(navigation_comp.path),
        path_index=navigation_comp.path_index,
        target_id=navigation_comp.planned_target_id,
    )
