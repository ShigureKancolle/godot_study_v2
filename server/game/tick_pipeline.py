# coding=utf-8
import game.systems.comp_system as comp_system
import game.command_router as command_router
import game.events as event
import game.world as game_world
import game.commands as command
from typing import Generator

class TickPipeline:
    def __init__(self):
        self._systems: list[comp_system.CompSystem] = []
        self._router: command_router.CommandRouter = None

    def tick(self, dt: float):
        pass

    def dispatch(self, world: game_world.GameWorld, command: command.Command) -> Generator[event.Event, None, None]:
        return self._router.dispatch(world, command)

    def update(self, world: game_world.GameWorld, dt: float) -> Generator[event.Event, None, None]:
        for system in self._systems:
            events = system.update(world, dt)
            yield from events

    def add_system(self, system: comp_system.CompSystem):
        self._systems.append(system)

    def remove_system(self, system: comp_system.CompSystem):
        system = self._systems.pop(system)
        del system

    def set_command_router(self, router: command_router.CommandRouter):
        self._router = router