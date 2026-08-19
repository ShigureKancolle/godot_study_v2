# coding=utf-8

import game.model.components as comps
import game.commands as command
import game.world as game_world
import game.events as event
import game.tools.collision as collision

class CompSystem:
    def __init__(self):
        self._need_update = False

    def apply_command(world: game_world.GameWorld, command: command.Command) -> list[event.Event]:
        pass

    def update(world: game_world.GameWorld, dt: float) -> list[event.Event]:
        pass


class MovementCompSystem(CompSystem):

    def apply_command(self, world: game_world.GameWorld, command: command.Command) -> list[event.Event]:
        entity = world.get_entity(command.entity_id)
        move_comp = entity.get_component(comps.MovementComponent) if entity is not None else None
        if move_comp is None:
            return []


        changed = move_comp.moving != command.moving or move_comp.dir_x != command.dir_x or move_comp.dir_y != command.dir_y
        move_comp.dir_x = command.dir_x
        move_comp.dir_y = command.dir_y
        move_comp.moving = command.moving
        move_comp.input_changed = changed

        return []

    def update(self, world: game_world.GameWorld, dt: float) -> list[event.Event]:
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

            position_changed = transform_comp.x != old_x or transform_comp.y != old_y

            if move_comp.input_changed or position_changed:
                
                events.append(event.EntityMovedEvent(
                    entity.entity_info.entity_id,
                    transform_comp.x,
                    transform_comp.y,
                    move_comp.moving
                ))

            move_comp.input_changed = False

        return events

            

                       
