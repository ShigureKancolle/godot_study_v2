# coding=utf-8
"""游戏 System：校验命令、修改 GameWorld 组件并产生领域事件。"""

import math
from game.entity_projector import project_entity_snapshot
import game.model.components as comps
import game.tools.collision as collision
import game.model.config_loader as config_loader
import game.events as event
import typing
if typing.TYPE_CHECKING:
    import game.commands as command
    import game.world as game_world
    
    
    

class CompSystem:
    def __init__(self, *args, **kwargs):
        self._need_update = False
        self.init(*args, **kwargs)

    def init(self, *args, **kwargs):
        pass

    def apply_command(world: "game_world.GameWorld", command: "command.Command") -> list[event.Event]:
        raise NotImplementedError("apply_command must be implemented in subclasses")

    def update(world: "game_world.GameWorld", dt: float) -> list[event.Event]:
        raise NotImplementedError("update must be implemented in subclasses")

    @staticmethod
    def reject(command: "command.WorldCommand", reason_code: str, reason_message: str):
        return [event.CommandRejectedEvent(
            connection_id=command.connection_id,
            command_name=type(command).__name__,
            reason_code=reason_code,
            reason_message=reason_message,
        )]


class MovementCompSystem(CompSystem):

    def apply_command(self, world: "game_world.GameWorld", command: "command.MoveCommand") -> list[event.Event]:
        entity = world.get_entity(command.entity_id)
        if entity is None:
            return self.reject(command, "ENTITY_NOT_FOUND", "受控实体不存在")

        if not math.isfinite(command.dir_x) or not math.isfinite(command.dir_y):
            return self.reject(command, "NON_FINITE_DIRECTION", "移动方向必须由有限数构成")

        move_comp = entity.get_component(comps.MovementComponent)
        if move_comp is None:
            return self.reject(command, "MOVEMENT_NOT_SUPPORTED", "该实体不能移动")
        if move_comp.is_locked:
            self._stop(move_comp)
            return self.reject(command, "MOVEMENT_LOCKED", "该实体的移动已被锁定")

        transform_comp = entity.get_component(comps.TransformComponent)
        combat_comp = entity.get_component(comps.CombatComponent)
        if transform_comp is None:
            return self.reject(command, "INVALID_MOVEMENT_ENTITY", "该实体缺少移动所需组件")

        if combat_comp is not None and combat_comp.is_dead:
            self._stop(move_comp)
            return self.reject(command, "ENTITY_DEAD", "死亡实体不能移动")

        changed = move_comp.moving != command.moving or move_comp.dir_x != command.dir_x or move_comp.dir_y != command.dir_y
        move_comp.dir_x = command.dir_x
        move_comp.dir_y = command.dir_y
        move_comp.moving = command.moving
        move_comp.input_changed = changed
        move_comp.anim_state = "run" if command.moving else "idle"

        facing_comp = entity.get_component(comps.FacingComponent)
        if  facing_comp and changed and (command.dir_x != 0.0 or command.dir_y != 0.0):
            facing_comp.facing = (command.dir_x, command.dir_y)

        return []

    @staticmethod
    def _stop(move_comp: comps.MovementComponent):
        move_comp.dir_x = 0.0
        move_comp.dir_y = 0.0
        move_comp.moving = False
        move_comp.input_changed = True
        move_comp.anim_state = "idle"

    def update(self, world: "game_world.GameWorld", dt: float) -> list[event.Event]:
        events: list[event.Event] = []
        for entity in world.entities_with([comps.MovementComponent, comps.TransformComponent]):
            move_comp = entity.get_component(comps.MovementComponent)
            transform_comp = entity.get_component(comps.TransformComponent)
            combat_comp = entity.get_component(comps.CombatComponent)

            if move_comp.is_locked or combat_comp is not None and combat_comp.is_dead:
                # 被限制了不能移动的entity 通知客户端停止移动了
                was_active = move_comp.moving or move_comp.dir_x != 0.0 or move_comp.dir_y != 0.0
                self._stop(move_comp)
                if was_active:
                    events.append(event.EntityMovedEvent(
                        entity.entity_id,
                        transform_comp.x,
                        transform_comp.y,
                        False,
                        "idle",
                    ))
                move_comp.input_changed = False
                continue

            if not move_comp.moving or move_comp.dir_x == 0.0 and move_comp.dir_y == 0.0:
                dir_vec = collision.Vector2(0.0, 0.0)
                move_comp.moving = False
            else:
                dir_vec = collision.Vector2(move_comp.dir_x, move_comp.dir_y).normalized()

            old_x = transform_comp.x
            old_y = transform_comp.y
            new_x = old_x + dir_vec.x * move_comp.speed * dt
            new_y = old_y + dir_vec.y * move_comp.speed * dt

            # 验证目标点是否可行 
            if not self.check_can_move(new_x, new_y):
                continue

            transform_comp.x = new_x
            transform_comp.y = new_y

            

            position_changed = transform_comp.x != old_x or transform_comp.y != old_y

            if move_comp.input_changed or position_changed:
                facing = (dir_vec.x, dir_vec.y)
                if facing_comp := entity.get_component(comps.FacingComponent):
                    facing = facing_comp.facing
                
                events.append(event.EntityMovedEvent(
                    entity.entity_id,
                    transform_comp.x,
                    transform_comp.y,
                    move_comp.moving,
                    move_comp.anim_state,
                    facing,
                ))

            move_comp.input_changed = False

        return events

    def check_can_move(self, x: float, y: float):
        return True


class JoinCompSystem(CompSystem):
    def apply_command(self, world: "game_world.GameWorld", command: "command.JoinCommand") -> list[event.Event]:
        print(f"apply_command: joinCommand   account: {command.account}")

           
        for entity in world.entities_with([comps.PlayerComponent]):
            if entity.get_component(comps.PlayerComponent).account_id == command.account:
                print(f"apply_command: joinCommand    entity joined  account: {command.account}")
                return self.reject(command, "ALREADY_JOINED", "该账号在当前世界中已经存在实体")
        # todo 这个playername应该放存档？ 存档没有才用客户端的
        entity = world.create_player(command.account, command.player_name)

        if entity is None:
            print(f"apply_command: joinCommand   entity is None")
            return self.reject(command, "CREATE_ENTITY_FAILED", "无法创建玩家实体")
        
        transform_comp = entity.get_component(comps.TransformComponent)
        if transform_comp is None:
            print(f"apply_command: joinCommand   transform_comp is None")
            return self.reject(command, "INVALID_PLAYER_ENTITY", "创建的玩家实体缺少 TransformComponent")

        entity_snapshot = project_entity_snapshot(entity)
        env = event.EntityJoinedEvent(
            command.account,
            entity_snapshot
        )

        print(f"apply_command: joinCommand   return env account: {command.account}")
        return [env]

    def update(self, world: "game_world.GameWorld", dt: float) -> list[event.Event]:
        return []

class AttackCompSystem(CompSystem):
    def init(self, *args, **kwargs):
        pass

    def apply_command(self, world: "game_world.GameWorld", command: "command.AttackCommand") -> list[event.Event]:
        attacker = world.get_entity(command.entity_id)
        if attacker is None:
            return self.reject(command, "ENTITY_NOT_FOUND", "攻击实体不存在")

        transform_comp = attacker.get_component(comps.TransformComponent)
        if transform_comp is None:
            return self.reject(command, "ATTACK_NOT_SUPPORTED", "该实体不能攻击")
               
        attack_config = config_loader.get_attack_config(command.attack_id)
        if attack_config is None:
            return self.reject(command, "ATTACK_CONFIG_NOT_FOUND", "请求的攻击没有对应配置")
     
        # 获取攻击形状
        shape_list = attack_config.shape_list
        for shape in shape_list:
            pass

        # 可能需要维护一个攻击队列，用于处理攻击的顺序
        return []

    def update(self, world: "game_world.GameWorld", dt: float) -> list[event.Event]:
        return []


class LeaveCompSystem(CompSystem):
    def apply_command(self, world: "game_world.GameWorld", command: "command.LeaveCommand") -> list[event.Event]:
        print(f"leave command: {command.account}")
        entity = world.get_entity(command.entity_id)
        if not entity:
            return []

        player_comp = entity.get_component(comps.PlayerComponent)
        if player_comp is None:
            return []

        if player_comp.account_id != command.account:
            return []

        removed = world.remove_entity(entity.entity_id)
        if removed is None:
            return []
        
        return [event.EntityRemovedEvent(
            entity.entity_id,
            command.account
        )]
        
    def update(self, world: "game_world.GameWorld", dt: float) -> list[event.Event]:
        return []
    
                       
