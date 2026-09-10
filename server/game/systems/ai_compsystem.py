# coding=utf-8
"""AI组件系统。"""

import math

from game.model import config_loader, navigation_grid
from game.model.navigation_component import NavigationComponent
from game.systems.comp_system import CompSystem
from game.model.ai_component import AIComponent
from game.model.combat_component import CombatComponent
import game.model.components as comps
import game.events as events
import logging
import game.commands as commands
import dataclasses
import typing
if typing.TYPE_CHECKING:
    
    import game.world as world
    from game.model.entity import Entity

logger = logging.getLogger(__name__)

@dataclasses.dataclass
class AIEntityComps:
    ai_comp: AIComponent
    move_comp: comps.MovementComponent
    transform_comp: comps.TransformComponent

@dataclasses.dataclass
class TargetEntityComps:
    move_comp: comps.MovementComponent
    transform_comp: comps.TransformComponent

class AICompSystem(CompSystem):
    """AI组件系统。"""
    def init(self, *args, **kwargs):
        self._ai_commands: list[commands.WorldCommand] = []

    def apply_command(self, world: "world.GameWorld", command: "commands.WorldCommand") -> list[events.Event]:
        # 客户端不会发送 AI状态变更请求
        return []

    def decide(self, world, dt) -> "list[commands.WorldCommand]":
        self._ai_commands.clear()
        self.update(world, dt)
        return self._ai_commands

    def update(self, world: "world.GameWorld", dt: float) -> list[events.Event]:
        ai_entities = world.entities_with(AIComponent)
        for ai_entity in ai_entities:
            ai_entity_comps = self.countdown_all_timer(ai_entity, dt)
            if not ai_entity_comps:
                continue

            _, target_comps = self.check_ai_target_vaild(ai_entity, world)
            if target_comps is None:
                ai_entity_comps.ai_comp.state_target_id = ""
                self.find_target(world, ai_entity)

            if self.try_attack(world, dt, ai_entity):
                continue
            if self.try_chase(world, dt, ai_entity):
                continue
            if self.try_idle(world, dt, ai_entity):
                continue

        # 这个系统理论上不该产生事件
        return []


    def try_attack(self, world: "world.GameWorld", dt: float, attacker: "Entity") -> bool:
        """尝试攻击。"""
        ai_entity_comps, target_entity_comps = self.check_ai_target_vaild(attacker, world)
        if ai_entity_comps is None or target_entity_comps is None:
            return False

        ai_entity_comps: AIEntityComps
        target_entity_comps: TargetEntityComps

        _ai_comp: AIComponent = ai_entity_comps.ai_comp
        _transform_comp: comps.TransformComponent = ai_entity_comps.transform_comp
        params: config_loader.EntityAiConfig = config_loader.get_entity_ai_config(_ai_comp.config_name)
        _combat_comp: CombatComponent = attacker.get_component(CombatComponent)
        if _combat_comp is None:
            logger.error("_combat_comp is None")
            return False

        if _combat_comp.atk_countdown_ms > 0:
            # 攻击的时候不让做别的
            return True
        
        # 判断距离
        target_transform_comp: comps.TransformComponent = target_entity_comps.transform_comp
        distance = ((target_transform_comp.x - _transform_comp.x) ** 2 + (target_transform_comp.y - _transform_comp.y) ** 2)
        if distance > params.attack_distance ** 2:
            # logger.log(f"distance is {distance} which is greater than attack_distance {params.attack_distance}")
            return False

        # 停止移动
        move_command = commands.MoveCommand(attacker.entity_id, dir_x = 0.0, dir_y = 0.0, moving = False)
        self.append_ai_command(move_command)

        if _ai_comp.atk_interval_ms > 0:
            # 进入攻击范围但是攻击意图cd中，原地等待 本帧执行成功返回True
            return True
        
        # 转向目标
        rotate_command = commands.AtkRotateCommand(attacker.entity_id, atk_facing = -math.atan2(target_transform_comp.y - _transform_comp.y, target_transform_comp.x - _transform_comp.x))

        _ai_comp.state = "attack"
        logger.info(f"entity {attacker.entity_id} enter attack")
        # 发起攻击请求
        attack_command = commands.AttackCommand(attacker.entity_id, attack_id = params.attack_id)

        # 攻击意图cd
        _ai_comp.atk_interval_ms = params.attack_interval_ms

        self.append_ai_command(rotate_command, attack_command)

        # 这里在攻击结束前都不应该能够执行其他操作 
        return True

    def try_chase(self, world: "world.GameWorld", dt: float, attacker: "Entity") -> bool:
        """尝试追击。"""
        ai_entity_comps, target_entity_comps = self.check_ai_target_vaild(attacker, world)
        if ai_entity_comps is None or target_entity_comps is None:
            return False

        ai_entity_comps: AIEntityComps
        target_entity_comps: TargetEntityComps
        
        _ai_comp: AIComponent = ai_entity_comps.ai_comp
        _transform_comp: comps.TransformComponent = ai_entity_comps.transform_comp
        target_transform_comp: comps.TransformComponent = target_entity_comps.transform_comp
        _ai_params = config_loader.get_entity_ai_config(_ai_comp.config_name)

        move_dir_x = target_transform_comp.x - _transform_comp.x
        move_dir_y = target_transform_comp.y - _transform_comp.y
        # 判断距离
        if move_dir_x ** 2 + move_dir_y ** 2 > _ai_params.out_combat_distance ** 2:
            # logger.log(f"distance is {target_transform_comp.x + _transform_comp.y} which is greater than out_combat_distance {_ai_params.out_combat_distance}")
            _ai_comp.state_target_id = None
            return False

        # 寻路
        _navigation_comp: NavigationComponent = attacker.get_component(NavigationComponent)
        if _navigation_comp is None:
            # 转向目标
            rotate_command = commands.AtkRotateCommand(attacker.entity_id, atk_facing = -math.atan2(move_dir_y, move_dir_x))
            move_command = commands.MoveCommand(attacker.entity_id, dir_x = move_dir_x, dir_y = move_dir_y, moving = True)
            self.append_ai_command(rotate_command, move_command)
        else:
            current_tick = world.cur_tick()
            current_target_block = navigation_grid.world_pos_to_block(
                target_transform_comp.x,
                target_transform_comp.y,
                world.map_id,
            )
            target_changed = _navigation_comp.planned_target_id != _ai_comp.state_target_id

            if target_changed:
                # 换目标时旧的无路等待不再适用，当前 tick 立即查询新目标。
                self.find_path(world, attacker, target_entity_comps)
            elif not _navigation_comp.path:
                # 上次无路时等待到约定 tick，避免每 tick 重复执行 A*。
                if current_tick >= _navigation_comp.unreachable_retry_tick:
                    self.find_path(world, attacker, target_entity_comps)
            elif _ai_comp.state != "chase":
                # 从攻击等状态重新进入追逐时，立即按目标当前位置刷新路径。
                self.find_path(world, attacker, target_entity_comps)
            elif current_tick >= _navigation_comp.repath_not_before_tick:
                planned_target_block = _navigation_comp.planned_target_block
                block_dx = abs(current_target_block[0] - planned_target_block[0])
                block_dy = abs(current_target_block[1] - planned_target_block[1])
                block_distance = max(block_dx, block_dy)
                repath_distance = config_loader.get_navigation_ai_config().target_repath_distance_blocks
                if block_distance > repath_distance:
                    # 八方向寻路按二维切比雪夫距离判断，避免横纵变化相互抵消。
                    self.find_path(world, attacker, target_entity_comps)

            self.move_by_path(attacker, dt)

        _ai_comp.state = "chase"
        return True

    def try_idle(self, world: "world.GameWorld", dt: float, attacker: "Entity") -> bool:
        """尝试空闲。"""
        ai_entity_comps = self.check_ai_entity_vaild(attacker)
        if not ai_entity_comps:
            return False
        _ai_comp: AIComponent = ai_entity_comps.ai_comp

        if _ai_comp.state == "idle":
            # 已经是空闲状态了
            return True

        logger.info(f"entity {attacker.entity_id} enter idle")
        _ai_comp.state = "idle"
        move_command = commands.MoveCommand(attacker.entity_id, dir_x = 0.0, dir_y = 0.0, moving = False)
        self.append_ai_command(move_command)
        return True

    def find_target(self, world: "world.GameWorld", attacker: "Entity") -> bool:
        """查找目标。"""
        _ai_entity_comps = self.check_ai_entity_vaild(attacker)
        if not _ai_entity_comps:
            return False
        _ai_comp: AIComponent = _ai_entity_comps.ai_comp
        _transform_comp: comps.TransformComponent = _ai_entity_comps.transform_comp
        _ai_params = config_loader.get_entity_ai_config(_ai_comp.config_name)
        if _ai_params is None:
            logger.error("_ai_params is None")
            return False

        min_distance = float('inf')
        players = world.entities_with(comps.PlayerComponent)
        min_target_entity_id: str = ""
        for player in players:
            if player.is_dead():
                continue
            _p_transform_comp: comps.TransformComponent = player.get_component(comps.TransformComponent)
            if _p_transform_comp is None:
                logger.error("_p_transform_comp is None")
                continue

            dx = _p_transform_comp.x - _transform_comp.x
            dy = _p_transform_comp.y - _transform_comp.y
            if dx ** 2 + dy ** 2 > _ai_params.check_distance ** 2:
                continue

           
            if min_distance > dx ** 2 + dy ** 2:
                min_distance = dx ** 2 + dy ** 2
                min_target_entity_id = player.entity_id

        _ai_comp.state_target_id = min_target_entity_id
        return min_target_entity_id != ""

    def check_ai_entity_vaild(self, ai_entity: "Entity") -> AIEntityComps | None:
        """检查AI实体是否有效。"""
        if ai_entity is None:
            logger.error("ai_entity is None")
            return None
        # 尸体保留到死亡动画结束属于正常流程，期间不再参与 AI 决策。
        if ai_entity.is_dead():
            return None
        _ai_comp: AIComponent = ai_entity.get_component(AIComponent)
        if _ai_comp is None:
            logger.error("_ai_comp is None")
            return None
        _move_comp: comps.MovementComponent = ai_entity.get_component(comps.MovementComponent)
        if _move_comp is None:
            logger.error("_move_comp is None")
            return None
        _transform_comp: comps.TransformComponent = ai_entity.get_component(comps.TransformComponent)
        if _transform_comp is None:
            logger.error("_transform_comp is None")
            return None
        return AIEntityComps(ai_comp = _ai_comp, move_comp = _move_comp, transform_comp = _transform_comp)

    def check_ai_target_vaild(self, ai_entity: "Entity", world: "world.GameWorld") -> tuple[AIEntityComps, TargetEntityComps] | tuple[None, None]:
        """检查AI目标实体是否有效。"""
        _ai_entity_comps = self.check_ai_entity_vaild(ai_entity)
        if not _ai_entity_comps:
            return (None, None)
        _target_entity_id: str = _ai_entity_comps.ai_comp.state_target_id
        if _target_entity_id == "":
            return (None, None)
        _target_entity = world.get_entity(_target_entity_id)
        if not _target_entity:
            logger.error(f"_target_entity is None, target_entity_id = {_target_entity_id}")
            return (None, None)
        if _target_entity.is_dead():
            logger.error("_target_entity is dead")
            return (None, None)  
        _target_transform_comp: comps.TransformComponent = _target_entity.get_component(comps.TransformComponent)
        if _target_transform_comp is None:
            logger.error("_target_transform_comp is None")
            return (None, None)
        _target_move_comp: comps.MovementComponent = _target_entity.get_component(comps.MovementComponent)
        if _target_move_comp is None:
            logger.error("_target_move_comp is None")
            return (None, None)
            
        return (
            _ai_entity_comps,
            TargetEntityComps(move_comp = _target_move_comp, transform_comp = _target_transform_comp)
        )


    def countdown_all_timer(self, ai_entity: "Entity", dt: float) -> AIEntityComps | None:
        """倒计时所有定时器。"""
        _ai_entity_comps = self.check_ai_entity_vaild(ai_entity)
        if not _ai_entity_comps:
            return None

        _ai_comp: AIComponent = ai_entity.get_component(AIComponent)
        if _ai_comp.atk_interval_ms > 0:
            _ai_comp.atk_interval_ms -= dt * 1000
            _ai_comp.atk_interval_ms = max(0, _ai_comp.atk_interval_ms)

        return _ai_entity_comps

    def append_ai_command(self, *commands: commands.WorldCommand):
        """添加AI命令。"""
        if not commands:
            return

        self._ai_commands.extend(commands)

    def get_ai_commands(self) -> list[commands.WorldCommand]:
        """获取AI命令。"""
        return self._ai_commands

    def find_path(self, world: "world.GameWorld", ai_entity: "Entity", target_entity_comps: TargetEntityComps) -> bool:
        """寻路。"""
        _ai_comp: AIComponent = ai_entity.get_component(AIComponent)
        _transform_comp: comps.TransformComponent = ai_entity.get_component(comps.TransformComponent)
        _navigation_comp: NavigationComponent = ai_entity.get_component(NavigationComponent)
        _ai_params = config_loader.get_entity_ai_config(_ai_comp.config_name)
        target_transform_comp = target_entity_comps.transform_comp

        target_block = navigation_grid.world_pos_to_block(
            target_transform_comp.x,
            target_transform_comp.y,
            world.map_id,
        )
        path = world.pathfinder.find_path(
            (_transform_comp.x, _transform_comp.y),
            (target_transform_comp.x, target_transform_comp.y),
            _ai_params.out_combat_distance
        )
        if path:
            _navigation_comp.path = path
            _navigation_comp.path_index = 0
            _navigation_comp.path_index_loop = False
            _navigation_comp.planned_target_id = _ai_comp.state_target_id
            _navigation_comp.planned_target_block = target_block

            repath_interval_ms = config_loader.get_navigation_ai_config().min_path_hold_ms
            _navigation_comp.repath_not_before_tick = world.cur_tick() + world.milliseconds_to_ticks(repath_interval_ms)
            _navigation_comp.unreachable_retry_tick = 0
            return True
        else:
            _navigation_comp.clear_path()
            # 失败后仍记录本次目标，否则下一 tick 会被当作换目标并立即重试。
            _navigation_comp.planned_target_id = _ai_comp.state_target_id
            _navigation_comp.planned_target_block = target_block
            unreachable_retry_ms = config_loader.get_navigation_ai_config().unreachable_retry_ms
            _navigation_comp.unreachable_retry_tick = world.cur_tick() + world.milliseconds_to_ticks(unreachable_retry_ms)
            return False

    def move_by_path(self, attacker:"Entity", dt: float):
        """沿着路径移动。"""
        _transform_comp: comps.TransformComponent = attacker.get_component(comps.TransformComponent)
        _navigation_comp: NavigationComponent = attacker.get_component(NavigationComponent)

        # 一次tick的最小移动距离 
        _move_comp: comps.MovementComponent = attacker.get_component(comps.MovementComponent)
        dt_move_px = _move_comp.speed * dt
        while _navigation_comp.path_index < len(_navigation_comp.path):
            
        
            target_pos = _navigation_comp.path[_navigation_comp.path_index]
            path_dir_x = target_pos[0] - _transform_comp.x
            path_dir_y = target_pos[1] - _transform_comp.y

           
            if path_dir_x ** 2 + path_dir_y ** 2 < dt_move_px ** 2:
                # 到达目标点
                _navigation_comp.path_index += 1
                continue 
            
            rotate_command = commands.AtkRotateCommand(attacker.entity_id, atk_facing = -math.atan2(path_dir_y, path_dir_x))
            move_command = commands.MoveCommand(attacker.entity_id, dir_x = path_dir_x, dir_y = path_dir_y, moving = True)
            self.append_ai_command(rotate_command, move_command)
            return

        # 全部路径都走完了
        self.append_ai_command(commands.MoveCommand(attacker.entity_id, moving = False))

