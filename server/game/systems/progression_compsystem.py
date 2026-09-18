# coding=utf-8
"""进度组件系统。"""

from game.model import components as comps, config_loader
from game.systems.comp_system import CompSystem
import game.model.progression_component as progression_comp

import typing
if typing.TYPE_CHECKING:
    import game.commands as command
    import game.world as game_world


import game.events as event


class ProgressionCompSystem(CompSystem):
    """进度组件系统。"""

    def init(self, *args, **kwargs):
        self._upgrade_exp: dict[int, float] = {}
        ''' k: level, v: exp 保存了k级升到k+1级所需的经验'''

        self._max_level = config_loader.get_reward_config().progression.max_level
        total_exp = 0.0
        for i, exp in enumerate(config_loader.get_reward_config().progression.next_level_xp):
            total_exp += exp
            self._upgrade_exp[i+1] = total_exp


    def apply_command(self, world: "game_world.GameWorld", command: "command.WorldCommand") -> list[event.Event]:
        return []

    def update(self, world: "game_world.GameWorld", dt: float) -> list[event.Event]:
        return []

    def add_exp(self, world: "game_world.GameWorld", entity_id: str, exp: int):
        """添加经验"""
        events = []
        prog_comp: progression_comp.ProgressionComponent = world.get_entity(entity_id).get_component(progression_comp.ProgressionComponent)
        prog_comp.total_exp += exp

        # todo多人可能要分享经验给队友

        # 可能升级
        events.extend(self._check_upgrade(world))

        return events

    def _check_upgrade(self, world: "game_world.GameWorld") -> list[event.Event]:
        """检查升级"""

        events = []
        for entity in world.entities_with([progression_comp.ProgressionComponent, comps.PlayerComponent]):
            prog_comp: progression_comp.ProgressionComponent = entity.get_component(progression_comp.ProgressionComponent)
            cur_exp = prog_comp.total_exp

            while prog_comp.level in self._upgrade_exp:
                next_level_exp = self._upgrade_exp[prog_comp.level]
                if cur_exp < next_level_exp:
                    break

                prog_comp.level += 1
                # 升级消息
                events.append(event.EntityUpgradeEvent(entity_id=entity.entity_id, pre_level=prog_comp.level-1, cur_level=prog_comp.level))
                # 还有一个发奖 但是要先去roll奖

            events.append(event.EntityProgChangedEvent(entity_id=entity.entity_id, level=prog_comp.level, total_exp=cur_exp))

        return events

                    
                     
