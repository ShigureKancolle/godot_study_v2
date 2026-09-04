# coding=utf-8
"""死亡实体的延迟移除系统。"""

import game.events as event
import game.model.combat_component as combat_component
import game.model.components as components
import game.model.config_loader as config_loader
from game.systems.comp_system import CompSystem
import typing

if typing.TYPE_CHECKING:
    import game.world as game_world


class DeathSystem(CompSystem):
    """将已死亡实体保留至死亡动画时长结束，再从权威世界移除。"""

    def update(self, world: "game_world.GameWorld", dt: float) -> list[event.Event]:
        events: list[event.Event] = []
        for entity in world.entities_with([combat_component.CombatComponent]):
            combat: combat_component.CombatComponent = entity.get_component(combat_component.CombatComponent)
            if not combat.is_dead:
                continue

            timer = entity.get_component(components.DeathTimerComponent)
            if timer is None:
                timer = components.DeathTimerComponent(
                    remove_after_ms=config_loader.get_dead_duration_ms(entity.entity_config_key),
                )
                entity.add_component(timer)
                events.append(event.EntityDiedEvent(entity_id=entity.entity_id))

                if timer.remove_after_ms > 0:
                    continue

            timer.elapsed_ms += dt * 1000.0
            if timer.elapsed_ms < timer.remove_after_ms:
                continue

            removed = world.remove_entity(entity.entity_id)
            if removed is not None:
                events.append(event.EntityRemovedEvent(entity_id=entity.entity_id))

        return events
