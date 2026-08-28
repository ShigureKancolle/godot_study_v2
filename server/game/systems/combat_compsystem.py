# coding=utf-8
"""战斗组件系统。"""

from game.systems.comp_system import CompSystem
import game.events as event
import game.model.combat_component as combat_comp
import typing
if typing.TYPE_CHECKING:
    import game.commands as command
    import game.world as game_world


class CombatCompSystem(CompSystem):
    """战斗组件系统。"""
    def apply_command(self, world: "game_world.GameWorld", command: "command.AtkRotateCommand") -> list[event.Event]:
        entity = world.get_entity(command.entity_id)
        if entity is None:
            return self.reject(command, "ENTITY_NOT_FOUND", "受控实体不存在")
        _combat_comp = entity.get_component(combat_comp.CombatComponent)
        if _combat_comp is None:
            return self.reject(command, "COMPONENT_NOT_FOUND", "实体不存在战斗组件")

        if _combat_comp.atk_facing_locking:
            return self.reject(command, "COMPONENT_LOCKED", "实体战斗组件转向已锁定")

        if abs(_combat_comp.atk_facing - command.atk_facing) < 0.01:
            return []

        _combat_comp.atk_facing = command.atk_facing

        env = event.EntityAtkRotateEvent(
            entity_id=command.entity_id,
            atk_facing=command.atk_facing,
        )

        return [env]
        
    def update(self, world: "game_world.GameWorld", dt: float) -> list[event.Event]:
        return []