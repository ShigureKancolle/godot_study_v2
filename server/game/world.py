# coding=utf-8

import asyncio
import game.model.entity as entity
import game.commands as command
import game.events as event
import game.systems.comp_system as comp_system
import game.model.components as comps
import game.model.config_loader as config_loader
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
        self.register_command_handlers()

    async def start(self):
        pass

    # region loop
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
        return event.TickResult(
            server_tick=self._tick,
            events=events
        )

    # def update(self, dt: float):
    #     events = self.step(dt)
    #     return events

    # endregion loop


    # region command
    # def dispatch_command(self, command: command.Command):
    #     if self._command_router is None:
    #         raise ValueError("command router is not set")
        
    #     return self._command_router.dispatch(self, command)

    def enqueue_command(self, command: command.Command):
        self._pending_commands.append(command)

    def register_command_handlers(self):
        import game.command_router as command_router
        import game.tick_pipeline as tick_pipeline
        self._command_router = command_router.CommandRouter()
        self._tick_pipeline = tick_pipeline.TickPipeline()
        self._tick_pipeline.set_command_router(self._command_router)

        # move 
        movement_comp_system = comp_system.MovementCompSystem()
        self._command_router.register(command.MoveCommand, movement_comp_system.apply_command)
        self._tick_pipeline.add_system(movement_comp_system)   

        # join
        join_comp_system = comp_system.JoinCompSystem()
        self._command_router.register(command.JoinCommand, join_comp_system.apply_command)
        self._tick_pipeline.add_system(join_comp_system)

        # attack
        attack_comp_system = comp_system.AttackCompSystem()
        self._command_router.register(command.AttackCommand, attack_comp_system.apply_command)
        self._tick_pipeline.add_system(attack_comp_system)

        # login
        login_comp_system = comp_system.LoginCompSystem()
        self._command_router.register(command.LoginCommand, login_comp_system.apply_command)
        self._tick_pipeline.add_system(login_comp_system)

    # endregion command

    # region entity
    def get_entity(self, entity_id: str) -> "entity.Entity":
        return self._entites.get(entity_id)

    def add_entity(self, entity: entity.Entity):
        self._entites[entity.entity_id] = entity

    def get_entities(self) -> list["entity.Entity"]:
        return list(self._entites.values())

    def entities_with(self, component_type: list[type]) -> list["entity.Entity"]:
        res = [entity for entity in self.get_entities() if all(comp_type in entity.get_comp_types() for comp_type in component_type)]
        return res
    
    # endregion entity

    # region player
    def create_player(self, account: str) -> "entity.Entity":
        entity_id = f"player: {account}_{self._tick}"
        speed = config_loader.get_speed(entity.EntityType.PLAYER)
        player = entity.Entity(entity_id=entity_id)
        player.add_component(comps.PlayerComponent(account_id=account))
        player.add_component(comps.TransformComponent(x=0.0, y=0.0))
        player.add_component(comps.MovementComponent(speed=speed))
        player.add_component(comps.FacingComponent(facing=0.0))
        player.add_component(comps.CombatComponent())
        self.add_entity(player)
        return player

    # endregion player

    
    
