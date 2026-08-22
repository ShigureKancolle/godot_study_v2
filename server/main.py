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
from app.bootstrap import build_client_router

# 注册handler
import protocol.handlers

async def main():
    print("main() function is running...")
    build_client_router()
    socket = websocket_server.WebSocketServer()
    try:
        await socket.start()
    except Exception as e:
        print(e)
        socket.close()

def test_server():
    import proto.generated.game_pb2 as game_pb2
    import protocol.router as router
    import transport.connection_registry as connection_registry
    print("test_server() function is running...")


   
if __name__ == '__main__':
    print("server start")
    # asyncio.run(main())
    if "--test" in sys.argv:
        test_server()
    else:
        asyncio.run(main())
    print("server end")
