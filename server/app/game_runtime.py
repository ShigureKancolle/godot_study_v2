# coding=utf-8

import time
import asyncio
import logging
import typing
if typing.TYPE_CHECKING:
    import game.world as game_world
    import transport.game_protocol_adapter as game_protocol_adapter

logger = logging.getLogger(__name__)
TICK_RATE = 30
FIXED_DT = 1.0 / TICK_RATE

class GameRuntime:
    def __init__(self, world: game_world.GameWorld, protocol_adapter: game_protocol_adapter.GameProtocolAdapter):
        self._protocol_adapter = protocol_adapter
        self._world = world
        self._running = False

    async def run(self):
        self._running = True
        next_tick_at = time.monotonic()

        # 服务端游戏主循环
        while self._running:
            try:
            # 固定推进一次世界
                result = self._world.step(FIXED_DT)

                self._protocol_adapter.publish_tick_result(result)
            except asyncio.CancelledError:
                # 服务端正常关闭
                raise

            except Exception:
                logger.exception(f"游戏帧运行失败： server_tick={getattr(self._world, "_tick", "unknown")}")

            next_tick_at += FIXED_DT
            wait_seconds = next_tick_at - time.monotonic()
            await asyncio.sleep(max(0.0, wait_seconds))

