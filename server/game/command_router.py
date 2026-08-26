# coding=utf-8
"""将每种 WorldCommand 映射到唯一负责它的游戏 System。"""

import game.commands as command
import game.systems.comp_system as comp_system
import game.events as event
import typing
if typing.TYPE_CHECKING:
    import game.world as world

class CommandRouter:
    def __init__(self):
        self._handlers: dict[type, callable] = {}
        self._update_systems: list[comp_system.CompSystem] = []

    def register(self, command_type: type, handler: callable):
        self._handlers[command_type] = handler

    def dispatch(self, world: "world.GameWorld", command: command.WorldCommand):
        command_type = type(command)
        handler = self._handlers.get(command_type)
        if handler is None:
            return [event.CommandRejectedEvent(
                connection_id=command.connection_id,
                command_name=command_type.__name__,
                reason_code="COMMAND_NOT_REGISTERED",
                reason_message="没有游戏 System 负责该命令类型",
            )]
        return handler(world, command)
