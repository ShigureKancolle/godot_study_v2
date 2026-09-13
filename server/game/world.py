# coding=utf-8
"""单房间权威世界：持有实体、待处理命令和 tick 状态。"""

import asyncio
import logging
from game.model.ai_component import AIComponent
import game.model.entity as entity
import game.commands as command
import game.events as event
from game.model.navigation_component import NavigationComponent
from game.systems.ai_compsystem import AICompSystem
import game.systems.comp_system as comp_system
import game.systems.combat_compsystem as combat_comp_system
import game.systems.game_mode.game_mode as game_mode_module
import game.model.components as comps
import game.model.combat_component as combat_component
import game.model.config_loader as config_loader
import game.model.navigation_grid as navigation_grid
import game.tools.pathfinder as pathfinder
import game.systems.game_mode.survival_mode as survival_mode_module
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
    current_game_mode = survival_mode_module.SurvivalMode()
    game_room = GameWorld(current_game_mode)

# endregion

room_id = 0

def get_room_id():
    global room_id
    room_id += 1
    return f"room_{room_id:04d}"

class GameWorld:
    def __init__(self, current_game_mode: game_mode_module.GameMode | None = None):
        self.room_id: str = get_room_id()
        self._entites: dict[str, entity.Entity] = {}
        self._enemys: dict[str, dict[str, entity.Entity]] = {}
        self._pending_commands: list[command.Command] = []
        self._tick: int = 0
        self._entity_idx: int = 0
        self._command_router: "command_router.CommandRouter" = None
        self._tick_pipeline: "tick_pipeline.TickPipeline" = None
        self._ai_comp_system: AICompSystem = None
        self._game_mode = current_game_mode if current_game_mode is not None else game_mode_module.GameMode()
        self._system_instances: dict[type[comp_system.CompSystem], comp_system.CompSystem] = {}
        self.map_id: str = navigation_grid.TEST_MAP_ID
        self.pathfinder = pathfinder.PathFinder(self.map_id)

        self.init_pipeline()
        self.register_common_command_handlers()
        self.register_game_mode_command_handlers()
        self.register_update_system()
        self.register_always_update_system()

    async def start(self):
        # 在这里初始化gamemode
        pass

    def get_next_entity_idx(self):
        self._entity_idx += 1
        return self._entity_idx

    # region loop
    def step(self, dt: float):
        if dt <= 0:
            raise ValueError("dt must be greater than 0")

        events: list[event.Event] = []
        events.extend(self(self._game_mode.before_step(self, dt)))
        commands = self._pending_commands
        self._pending_commands = []

        for cur_command in commands:
            try:
                events.extend(self._tick_pipeline.dispatch(self, cur_command))
            except Exception:
                logger.exception(
                    f"执行Command失败： server_tick={self._tick}, command={type(cur_command).__name__}, {cur_command}"
                )

        if self._game_mode.can_update_system(game_mode_module.SystemScope.GAMEPLAY):
            # AI 操作要在 pipeline 的 update 之前，否则 AI 命令会慢一帧。
            ai_commands = self._ai_comp_system.decide(self, dt)
            for ai_command in ai_commands:
                try:
                    events.extend(self._tick_pipeline.dispatch(self, ai_command))
                except Exception:
                    logger.exception(
                        f"执行Command失败： server_tick={self._tick}, command={type(ai_command).__name__}, {ai_command}"
                    )
        
        events.extend(list(self._tick_pipeline.update(self, dt)))
        events.extend(self._game_mode.after_step(self, dt))

        self._tick += 1
        return event.TickResult(
            server_tick=self._tick,
            events=events
        )

    def enqueue_command(self, command: command.WorldCommand):
        self._pending_commands.append(command)

    def init_pipeline(self):
        """初始化tick pipeline。"""
        import game.command_router as command_router
        import game.tick_pipeline as tick_pipeline
        self._command_router = command_router.CommandRouter()
        self._tick_pipeline = tick_pipeline.TickPipeline()
        self._tick_pipeline.set_command_router(self._command_router)

    @property
    def game_mode(self) -> game_mode_module.GameMode:
        """返回当前世界独占的游戏模式实例。"""
        return self._game_mode

    def register_system(
        self,
        system_type: type[comp_system.CompSystem],
        command_type: type[command.WorldCommand] | None = None,
        command_scope: game_mode_module.CommandScope = game_mode_module.CommandScope.GAMEPLAY,
        update_scope: game_mode_module.SystemScope | None = None,
    ) -> comp_system.CompSystem:
        """复用同一个系统实例注册命令处理和周期更新。"""
        system = self._system_instances.get(system_type)
        if system is None:
            system = system_type()
            self._system_instances[system_type] = system

        if command_type is not None:
            self._command_router.register(command_type, system.apply_command, command_scope)
        if update_scope is not None:
            self._tick_pipeline.add_system(system, update_scope)
        return system

    def register_common_command_handlers(self):
        """注册通用命令处理函数。"""
        import game.systems.spawn_compsystem as spawn_compsystem

        self.register_system(comp_system.MovementCompSystem, command.MoveCommand)
        self.register_system(
            comp_system.JoinCompSystem,
            command.JoinCommand,
            game_mode_module.CommandScope.LIFECYCLE,
        )
        self.register_system(comp_system.AttackCompSystem, command.AttackCommand)
        self.register_system(
            comp_system.LeaveCompSystem,
            command.LeaveCommand,
            game_mode_module.CommandScope.LIFECYCLE,
        )
        self.register_system(combat_comp_system.CombatCompSystem, command.AtkRotateCommand)
        self.register_system(spawn_compsystem.SpawnEnemySystem, command.SpawnEnemyCommand)


    def register_game_mode_command_handlers(self):
        """注册游戏模式命令处理函数。"""
        self._game_mode.register_command_handlers(self._command_router)

    def register_update_system(self):
        """注册更新系统。"""
        import game.systems.death_system as death_system

        self.register_system(comp_system.MovementCompSystem, update_scope=game_mode_module.SystemScope.GAMEPLAY)
        self.register_system(comp_system.AttackCompSystem, update_scope=game_mode_module.SystemScope.GAMEPLAY)
        self.register_system(combat_comp_system.CombatCompSystem, update_scope=game_mode_module.SystemScope.GAMEPLAY)
        self.register_system(death_system.DeathSystem, update_scope=game_mode_module.SystemScope.GAMEPLAY)

        self._ai_comp_system = self.register_system(AICompSystem)

    def register_always_update_system(self):
        """注册始终更新系统。"""
        # 当前没有需要在玩法暂停期间按 dt 推进的通用系统。
        pass

    def cur_tick(self) -> int:
        return self._tick

    def milliseconds_to_ticks(self, milliseconds: int, tick_rate: int = 0) -> int:
        '''将毫秒向上取整为tick数。tick_rate为每秒tick数'''
        if tick_rate <= 0:
            # 这个tickrate也许要放在config里？
            import app.game_runtime as game_runtime
            tick_rate = game_runtime.TICK_RATE

        return (milliseconds * tick_rate + 999) // 1000

    # endregion command

    # region entity
    def get_entity(self, entity_id: str) -> "entity.Entity":
        return self._entites.get(entity_id)

    def add_entity(self, entity: entity.Entity):
        self._entites[entity.entity_id] = entity

    def get_entities(self) -> list["entity.Entity"]:
        return list(self._entites.values())

    def entities_with(self, component_type: list[type]) -> list["entity.Entity"]:
        if type(component_type) == type:
            component_type = [component_type]
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
        player.hit_box.hit_layer = capability.hit_layer

        player.add_component(comps.PlayerComponent(account_id=account, player_name=player_name))
        player.add_component(comps.TransformComponent(x=0.0, y=0.0))
        player.add_component(comps.MovementComponent(speed=speed))
        player.add_component(comps.FacingComponent(facing=(0.0, 0.0)))
        combat_comp = combat_component.CombatComponent()
        combat_comp.load_combat_config("player")
        combat_comp.attack_mask = capability.attack_mask
        
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
        enemy.hit_box.hit_layer = capability.hit_layer

        if capability.ai_id:
            enemy.add_component(AIComponent(config_name=capability.ai_id))
            enemy.add_component(NavigationComponent())
        speed = config_loader.get_speed(enemy_type)
        enemy.add_component(comps.MovementComponent(speed=speed))
        enemy.add_component(comps.TransformComponent(x=x, y=y))
        combat_comp = combat_component.CombatComponent()
        combat_comp.load_combat_config(enemy_type)
        combat_comp.attack_mask = capability.attack_mask
        enemy.add_component(combat_comp)
        self.add_entity(enemy)

        if enemy_type not in self._enemys:
            self._enemys[enemy_type] = {}
        self._enemys[enemy_type][enemy.entity_id] = enemy
        return enemy

    def get_enemies(self, enemy_type: str = None) -> list["entity.Entity"]:
        if enemy_type is None:
            return list(self._enemys.values())
        return list(self._enemys[enemy_type].values())

    def enemy_count(self, enemy_type: str | list[str] = None) -> int:
        if enemy_type is None:
            return len(self._enemys)
        elif isinstance(enemy_type, str):
            enemy_type = [enemy_type]
        return sum([len(self._enemys[_enemy_type]) for _enemy_type in enemy_type if _enemy_type in self._enemys])

    # endregion enemy

    
    
