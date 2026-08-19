# coding=utf-8
import sys
import asyncio
import game.world as world
import game.model.entity as entity
import game.commands as command
import game.model.components as comps
import game.command_router as command_router
import game.systems.comp_system as comp_system
import game.tick_pipeline as tick_pipeline

async def main():
    print("main() function is running...")
    server = None

def test_server():
    print("test_server() function is running...")
    pipeline = register_command_handlers()
    gw = world.GameWorld()
    gw.set_tick_pipeline(pipeline)
    player = entity.Entity(entity_info=entity.EntityInfo(entity_id="1", entity_type=entity.EntityType.PLAYER))
    player.add_component(comps.TransformComponent(x=0.0, y=0.0))
    player.add_component(comps.MovementComponent(speed=100.0))
    player.add_component(comps.FacingComponent(facing=0.0))
    gw.add_entity(player)

    for i in range(10):
        print(i)
        if i % 3 == 0:
            print("move")
            gw.enqueue_command(command.MoveCommand("1", 1.0, 1.0, True))
        elif i % 3 == 1:
            print("empty")
            # gw.enqueue_command(command.MoveCommand("1", 0.0, 0.0, False))
        else:
            print("stop")
            gw.enqueue_command(command.MoveCommand("1", 0.0, 0.0, False))


        events = gw.step(0.1)
        print(gw.get_entity("1"))
        print(events)

def register_command_handlers():
    router = command_router.CommandRouter()
    pipeline = tick_pipeline.TickPipeline()
    pipeline.set_command_router(router)
    movement_comp_system = comp_system.MovementCompSystem()
    router.register(command.MoveCommand, movement_comp_system.apply_command)
    pipeline.add_system(movement_comp_system)
    return pipeline
   
if __name__ == '__main__':
    print("server start")
    # asyncio.run(main())
    if "--test" in sys.argv:
        test_server()
    else:
        asyncio.run(main())
    print("server end")
