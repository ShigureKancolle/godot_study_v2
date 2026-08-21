# coding=utf-8

import time
import asyncio
import typing
if typing.TYPE_CHECKING:
    import game.world as game_world

TICK_RATE = 30
FIXED_DT = 1.0 / TICK_RATE

class GameRuntime:
    def __init__(self, world: game_world.GameWorld, protocol_adapter):
        self._protocol_adapter = protocol_adapter
        self._world = world
        self._running = False

    async def run(self):
        self._running = True
        next_tick_at = time.monotonic()

        # 服务端游戏主循环
        while self._running:
            # 固定推进一次世界
            result = self._world.step(FIXED_DT)

            message = self._protocol_adapter


            next_tick_at += FIXED_DT
            wait_seconds = next_tick_at - time.monotonic()
            await asyncio.sleep(max(0.0, wait_seconds))

