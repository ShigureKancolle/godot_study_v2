# coding=utf-8
"""AI组件系统。"""

from game.model import config_loader
from game.systems.comp_system import CompSystem
from game.model.ai_component import AIComponent
from game.model.combat_component import CombatComponent
import game.events as events

import typing
if typing.TYPE_CHECKING:
    import game.commands as commands
    import game.world as world
    from game.model.entity import Entity


class AICompSystem(CompSystem):
    """AI组件系统。"""
    def apply_command(self, world: "world.GameWorld", command: "commands.WorldCommand") -> list[events.Event]:
        # 客户端不会发送 AI状态变更请求
        pass

    def update(self, world: "world.GameWorld", dt: float) -> list[events.Event]:
        ai_entities = world.entities_with(AIComponent)
        for ai_entity in ai_entities:
            if self.try_attack(world, dt, ai_entity):
                continue
            if self.try_chase():
                continue
            if self.try_idle():
                continue


    def try_attack(self, world: "world.GameWorld", dt: float, attakcer: "Entity") -> bool:
        """尝试攻击。"""
        _ai_comp: AIComponent = attakcer.get_component(AIComponent)
        _combat_comp: CombatComponent = attakcer.get_component(CombatComponent)
        params: config_loader.EntityAiConfig = config_loader.get_entity_ai_config(_ai_comp.config_name)

        if _ai_comp is None:
            return False
        if _combat_comp is None:
            return False
        
        if _combat_comp.atk_countdown_ms > 0:
            return False
        _combat_comp.atk_countdown_ms = int(dt * 1000)
        return True

    def try_chase(self):
        return False

    def try_idle(self):
        return False
