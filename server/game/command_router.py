# coding=utf-8
'''读表来给指令分配system'''
from typing import Generator

import game.commands as command
import game.world as world
import game.systems.comp_system as comp_system
import game.events as event

class CommandRouter:
    def __init__(self):
        self._handlers: dict[type, callable] = {}
        self._update_systems: list[comp_system.CompSystem] = []

    def register(self, command_type: type, handler: callable):
        self._handlers[command_type] = handler

    def dispatch(self, world: world.GameWorld, command: command.WorldCommand):
        command_type = type(command)
        handler = self._handlers.get(command_type)
        if handler is None:
            # todo print error
            raise []
        else:
            return handler(world, command)