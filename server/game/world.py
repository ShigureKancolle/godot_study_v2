# coding=utf-8
"""单房间权威世界：持有实体、待处理命令和 tick 状态。"""

import asyncio
import logging
import game.model.entity as entity
import game.commands as command
import game.events as event
import game.systems.comp_system as comp_system
import game.systems.combat_compsystem as combat_comp_system
import game.model.components as comps
import game.model.combat_component as combat_component
import game.model.config_loader as config_loader
from typing import Tuple
import typing
if typing.TYPE_CHECKING:
    import game.command_router as command_router
    import game.tick_pipeline as tick_pipeline

logger = logging.getLogger(__name__)


# region 单房间 先这样 到时候再加roommgr
game_room: "GameWorld" = None

def get_room():
    global game_room
    if game_room is None:
        create_room()
    return game_room

def create_room():
    global game_room
    game_room = GameWorld()

# endregion

room_id = 0

def get_room_id():
    global room_id
    room_id += 1
    return f"room_{room_id:04d}"

class GameWorld:
    def __init__(self):
        self.room_id: str = get_room_id()
        self._entites: dict[str, entity.Entity] = {}
        self._pending_commands: list[command.Command] = []
        self._tick: int = 0
        self._entity_idx: int = 0
        self._command_router: "command_router.CommandRouter" = None
        self._tick_pipeline: "tick_pipeline.TickPipeline" = None
        self.register_command_handlers()

    async def start(self):
        pass

    def get_next_entity_idx(self):
        self._entity_idx += 1
        return self._entity_idx

    # region loop
    def step(self, dt: float):
        if dt <= 0:
            raise ValueError("dt must be greater than 0")

        events: list[event.Event] = []
        commands = self._pending_commands
        self._pending_commands = []

        for cur_command in commands:
            try:
                events.extend(self._tick_pipeline.dispatch(self, cur_command))
            except Exception:
                logger.exception(
                    f"执行Command失败： server_tick={self._tick}, command={type(cur_command).__name__}, {cur_command}"
                )
        
        events.extend(list(self._tick_pipeline.update(self, dt)))

        self._tick += 1
        return event.TickResult(
            server_tick=self._tick,
            events=events
        )

    def enqueue_command(self, command: command.WorldCommand):
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

        # leave
        leave_comp_system = comp_system.LeaveCompSystem()
        self._command_router.register(command.LeaveCommand, leave_comp_system.apply_command)
        self._tick_pipeline.add_system(leave_comp_system)

        # combat
        _combat_comp_system = combat_comp_system.CombatCompSystem()
        self._command_router.register(command.AtkRotateCommand, _combat_comp_system.apply_command)
        self._tick_pipeline.add_system(_combat_comp_system)

        # spawn enemy
        import game.systems.spawn_compsystem as spawn_compsystem
        spawn_enemy_comp_system = spawn_compsystem.SpawnEnemySystem()
        self._command_router.register(command.SpawnEnemyCommand, spawn_enemy_comp_system.apply_command)
        self._tick_pipeline.add_system(spawn_enemy_comp_system)
        

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

    def remove_entity(self, entity_id: str) -> "entity.Entity | None":
        return self._entites.pop(entity_id, None)
    
    # endregion entity

    # region player
    def create_player(self, account: str, player_name: str = "", player_type="player") -> "entity.Entity":
        entity_id = f"player: {account}_{self.get_next_entity_idx()}"
        speed = config_loader.get_speed("player")
        player = entity.Entity(entity_id=entity_id, entity_config_key=player_type)
        player.entity_type = entity.EntityType.PLAYER

        capability = config_loader.get_capability(player_type)
        # 暂时只支持圆的
        assert capability.body_shape == config_loader.ShapeType.CIRCLE
        player.hit_box.shape_type = config_loader.ShapeType.CIRCLE
        player.hit_box.radius = getattr(capability.body_params, "radius", 0.0)

        player.add_component(comps.PlayerComponent(account_id=account, player_name=player_name))
        player.add_component(comps.TransformComponent(x=0.0, y=0.0))
        player.add_component(comps.MovementComponent(speed=speed))
        player.add_component(comps.FacingComponent(facing=(0.0, 0.0)))
        combat_comp = combat_component.CombatComponent()
        combat_comp.load_combat_config("player")
        player.add_component(combat_comp)
        self.add_entity(player)
        return player

    # endregion player

    # region enemy
    def create_enemy(self, enemy_type: str, x: float | Tuple[float, float], y: float=None) -> "entity.Entity":
        if isinstance(x, Tuple):
            x, y = x
        enemy = entity.Entity(entity_id=f"enemy: {enemy_type}_{self.get_next_entity_idx()}", entity_config_key=enemy_type)
        enemy.entity_type = entity.EntityType.ENEMY

        capability = config_loader.get_capability(enemy_type)
        # 暂时只支持圆的
        assert capability.body_shape == config_loader.ShapeType.CIRCLE
        enemy.hit_box.shape_type = config_loader.ShapeType.CIRCLE
        enemy.hit_box.radius = getattr(capability.body_params, "radius", 0.0)

        enemy.add_component(comps.TransformComponent(x=x, y=y))
        combat_comp = combat_component.CombatComponent()
        combat_comp.load_combat_config(enemy_type)
        enemy.add_component(combat_comp)
        self.add_entity(enemy)
        return enemy

    # endregion enemy

    
    
