# coding=utf-8
"""先执行待处理命令，再按确定顺序更新已注册的 System。"""
import typing
import game.systems.comp_system as comp_system
import game.command_router as command_router
import game.events as event
import game.commands as command
import game.systems.game_mode.game_mode as game_mode
import dataclasses
if typing.TYPE_CHECKING:
    import game.world as game_world

import logging
logger = logging.getLogger(__name__)


@dataclasses.dataclass
class SystemData:
    """保存系统实例及其暂停范围。"""
    system: comp_system.CompSystem
    scope: game_mode.SystemScope


class TickPipeline:
    def __init__(self):
        self._systems: list[SystemData] = []
        self._router: command_router.CommandRouter = None

    def dispatch(self, world: "game_world.GameWorld", command: command.WorldCommand):
        return self._router.dispatch(world, command)

    def update(self, world: "game_world.GameWorld", dt: float):
        for system_data in self._systems:
            if not world.game_mode.can_update_system(system_data.scope):
                continue
            system = system_data.system
            try:
                events = system.update(world, dt)
                yield from events
            except Exception:
                logger.exception(
                    f"System更新失败： server_tick={getattr(world, "_tick", "unknown")}, system={type(system).__name__}, dt={dt}"
                )

    def add_system(self, system: comp_system.CompSystem, scope: game_mode.SystemScope = game_mode.SystemScope.GAMEPLAY):
        if any(item.system is system for item in self._systems):
            return
        self._systems.append(SystemData(system, scope))

    def remove_system(self, system: comp_system.CompSystem):
        self._systems = [item for item in self._systems if item.system is not system]

    def set_command_router(self, router: command_router.CommandRouter):
        self._router = router
