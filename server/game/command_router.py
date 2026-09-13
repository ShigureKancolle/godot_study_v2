# coding=utf-8
"""将每种 WorldCommand 映射到唯一负责它的游戏 System。"""

import game.commands as command
import game.events as event
import game.systems.game_mode.game_mode as game_mode
import dataclasses
import typing
if typing.TYPE_CHECKING:
    import game.world as world

@dataclasses.dataclass
class HandlerData:
    handler: typing.Callable
    scope: game_mode.CommandScope


class CommandRouter:
    def __init__(self):
        self._handlers: dict[type, HandlerData] = {}

    def get_command_scope(self, command_type: type) -> game_mode.CommandScope | None:
        handler_data = self._handlers.get(command_type)
        if handler_data is None:
            return None
        return handler_data.scope

    def register(self, command_type: type, handler: typing.Callable, scope: game_mode.CommandScope = game_mode.CommandScope.GAMEPLAY):
        self._handlers[command_type] = HandlerData(handler, scope)

    def dispatch(self, world: "world.GameWorld", command: command.WorldCommand):
        command_type = type(command)
        handler_data = self._handlers.get(command_type)
        if handler_data is None:
            return [event.CommandRejectedEvent(
                connection_id=command.connection_id,
                command_name=command_type.__name__,
                reason_code="COMMAND_NOT_REGISTERED",
                reason_message="没有游戏 System 负责该命令类型",
            )]

        if not world.game_mode.can_dispatch_command(handler_data.scope):
            return [event.CommandRejectedEvent(
                connection_id=command.connection_id,
                command_name=command_type.__name__,
                reason_code="GAMEPLAY_PAUSED",
                reason_message="游戏玩法当前处于暂停状态",
            )]

        return handler_data.handler(world, command)
