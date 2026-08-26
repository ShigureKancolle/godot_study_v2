# coding=utf-8
"""先执行待处理命令，再按确定顺序更新已注册的 System。"""
import typing
import game.systems.comp_system as comp_system
import game.command_router as command_router
import game.events as event
import game.commands as command
if typing.TYPE_CHECKING:
    import game.world as game_world

import logging
logger = logging.getLogger(__name__)

class TickPipeline:
    def __init__(self):
        self._systems: list[comp_system.CompSystem] = []
        self._router: command_router.CommandRouter = None

    def dispatch(self, world: "game_world.GameWorld", command: command.WorldCommand):
        return self._router.dispatch(world, command)

    def update(self, world: "game_world.GameWorld", dt: float):
        for system in self._systems:
            try:
                events = system.update(world, dt)
                yield from events
            except Exception:
                logger.exception(
                    f"System更新失败： server_tick={getattr(world, "_tick", "unknown")}, system={type(system).__name__}, dt={dt}"
                )

    def add_system(self, system: comp_system.CompSystem):
        self._systems.append(system)

    def remove_system(self, system: comp_system.CompSystem):
        system = self._systems.pop(system)
        del system

    def set_command_router(self, router: command_router.CommandRouter):
        self._router = router
