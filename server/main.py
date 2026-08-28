# coding=utf-8
"""服务端装配入口：创建依赖并启动网络传输与游戏循环。"""
import sys
import asyncio
import logging
from app.app_runtime import AppRuntime
from app.game_runtime import GameRuntime
import game.world as world
from transport.game_protocol_adapter import GameProtocolAdapter
import transport.websocket_server as websocket_server
from app.bootstrap import build_client_router, register_adapter

# 注册handler
import protocol.handlers


logger = logging.getLogger(__name__)

async def main():
    logger.debug("main() function is running")
    game_world = world.get_room()
    protocol_adapter = GameProtocolAdapter(game_world)
    register_adapter(protocol_adapter)
    game_runtime = GameRuntime(world=game_world, protocol_adapter=protocol_adapter)
    app_runtime = AppRuntime(game_world)
    build_client_router()
    socket = websocket_server.WebSocketServer(app_runtime)
    await asyncio.gather(
        socket.start(),
        game_runtime.run()
    )

def test_server():
    import proto.generated.game_pb2 as game_pb2
    import protocol.router as router
    import transport.connection_registry as connection_registry
    logger.debug("test_server() function is running")


   
if __name__ == '__main__':
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    logger.info("服务端启动")
    # asyncio.run(main())
    if "--test" in sys.argv:
        test_server()
    else:
        asyncio.run(main())
    logger.info("服务端已停止")
