# coding=utf-8

import asyncio
import game.model.entity as entity
import game.commands as command
import game.events as event
import typing
if typing.TYPE_CHECKING:
    import game.command_router as command_router
    import game.tick_pipeline as tick_pipeline

class GameWorld:
    def __init__(self):
        self._entites: dict[str, entity.Entity] = {}
        self._pending_commands: list[command.Command] = []
        self._tick: int = 0
        self._command_router: "command_router.CommandRouter" = None
        self._tick_pipeline: "tick_pipeline.TickPipeline" = None

    async def start(self):
        pass

    def step(self, dt: float):
        if dt <= 0:
            raise ValueError("dt must be greater than 0")

        events: list[event.Event] = []
        commands = self._pending_commands
        self._pending_commands = []

        for command in commands:
            events.extend(self._tick_pipeline.dispatch(self, command))
        
        events.extend(list(self._tick_pipeline.update(self, dt)))

        self._tick += 1
        return events

    def update(self, dt: float):
        events = self.step(dt)
        return events

    def dispatch_command(self, command: command.Command):
        if self._command_router is None:
            raise ValueError("command router is not set")
        
        return self._command_router.dispatch(self, command)

    def enqueue_command(self, command: command.Command):
        self._pending_commands.append(command)

    def get_entity(self, entity_id: str) -> "entity.Entity":
        return self._entites.get(entity_id)

    def add_entity(self, entity: entity.Entity):
        self._entites[entity.entity_info.entity_id] = entity

    def get_entities(self) -> list["entity.Entity"]:
        return list(self._entites.values())

    def set_command_router(self, router: "command_router.CommandRouter"):
        self._command_router = router

    def entities_with(self, component_type: list[type]) -> list["entity.Entity"]:
        res = [entity for entity in self.get_entities() if all(comp_type in entity.get_comp_types() for comp_type in component_type)]
        return res

    def set_tick_pipeline(self, pipeline: "tick_pipeline.TickPipeline"):
        self._tick_pipeline = pipeline
    
