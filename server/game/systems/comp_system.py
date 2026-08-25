# coding=utf-8

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
        pass

    def update(world: "game_world.GameWorld", dt: float) -> list[event.Event]:
        pass


class MovementCompSystem(CompSystem):

    def apply_command(self, world: "game_world.GameWorld", command: "command.MoveCommand") -> list[event.Event]:
        entity = world.get_entity(command.entity_id)
        move_comp = entity.get_component(comps.MovementComponent) if entity is not None else None
        if move_comp is None or move_comp.is_locked:
            return []

        transform_comp = entity.get_component(comps.TransformComponent)
        combat_comp = entity.get_component(comps.CombatComponent)
        if transform_comp is None or combat_comp is None:
            return []

        if combat_comp.is_dead:
            return []

        changed = move_comp.moving != command.moving or move_comp.dir_x != command.dir_x or move_comp.dir_y != command.dir_y
        move_comp.dir_x = command.dir_x
        move_comp.dir_y = command.dir_y
        move_comp.moving = command.moving
        move_comp.input_changed = changed

        return []

    def update(self, world: "game_world.GameWorld", dt: float) -> list[event.Event]:
        events: list[event.Event] = []
        for entity in world.entities_with([comps.MovementComponent, comps.TransformComponent]):
            move_comp = entity.get_component(comps.MovementComponent)
            transform_comp = entity.get_component(comps.TransformComponent)

            if not move_comp.moving or move_comp.dir_x == 0.0 and move_comp.dir_y == 0.0:
                dir_vec = collision.Vector2(0.0, 0.0)
                move_comp.moving = False
            else:
                dir_vec = collision.Vector2(move_comp.dir_x, move_comp.dir_y).normalized()

            old_x = transform_comp.x
            old_y = transform_comp.y
            transform_comp.x += dir_vec.x * move_comp.speed * dt
            transform_comp.y += dir_vec.y * move_comp.speed * dt

            # 验证目标点是否可行 

            position_changed = transform_comp.x != old_x or transform_comp.y != old_y

            if move_comp.input_changed or position_changed:
                
                events.append(event.EntityMovedEvent(
                    entity.entity_id,
                    transform_comp.x,
                    transform_comp.y,
                    move_comp.moving
                ))

            move_comp.input_changed = False

        return events

            

class JoinCompSystem(CompSystem):
    def apply_command(self, world: "game_world.GameWorld", command: "command.JoinCommand") -> list[event.Event]:
        print(f"apply_command: joinCommand   account: {command.account}")

           
        for entity in world.entities_with([comps.PlayerComponent]):
            if entity.get_component(comps.PlayerComponent).account_id == command.account:
                print(f"apply_command: joinCommand    entity joined  account: {command.account}")
                return []
        
        entity = world.create_player(command.account)

        if entity is None:
            print(f"apply_command: joinCommand   entity is None")
            return []
        
        transform_comp = entity.get_component(comps.TransformComponent)
        if transform_comp is None:
            print(f"apply_command: joinCommand   transform_comp is None")
            return []

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
            return []

        transform_comp = attacker.get_component(comps.TransformComponent)
        if transform_comp is None:
            return []
               
        attack_config = config_loader.get_attack_config(command.attack_id)
        if attack_config is None:
            return []
     
        # 获取攻击形状
        shape_list = attack_config.shape_list
        for shape in shape_list:
            pass

        # 可能需要维护一个攻击队列，用于处理攻击的顺序
        return []

    def update(self, world: "game_world.GameWorld", dt: float) -> list[event.Event]:
        return []


class LoginCompSystem(CompSystem):
    def apply_command(self, world: "game_world.GameWorld", command: "command.LoginCommand") -> list[event.Event]:
        print(f"login command: {command.account}")
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
    
                       
