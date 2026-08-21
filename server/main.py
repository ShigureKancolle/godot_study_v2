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
import transport.websocket_server as websocket_server

async def main():
    print("main() function is running...")
    socket = websocket_server.WebSocketServer()
    try:
        await socket.start()
    except Exception as e:
        print(e)
        socket.close()

def test_server():
    print("test_server() function is running...")
    gw = world.GameWorld()
    player = gw.create_player("1")

    for i in range(10):
        print(i)
        if i % 3 == 0:
            print("move")
            gw.enqueue_command(command.MoveCommand(player.entity_id, 1.0, 1.0, True))
        elif i % 3 == 1:
            print("empty")
            # gw.enqueue_command(command.MoveCommand("1", 0.0, 0.0, False))
        else:
            print("stop")
            gw.enqueue_command(command.MoveCommand(player.entity_id, 0.0, 0.0, False))


        events = gw.step(0.1)
        print(gw.get_entity(player.entity_id))
        print(events)


   
if __name__ == '__main__':
    print("server start")
    # asyncio.run(main())
    if "--test" in sys.argv:
        test_server()
    else:
        asyncio.run(main())
    print("server end")
