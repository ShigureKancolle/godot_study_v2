# coding=utf-8
"""验证生存模式调试数据的数值快照、协议编码与同帧发布。"""

import asyncio
import unittest
from unittest.mock import patch

from game.events import EnemyBudgetData, EntityMovedEvent, LevelDebugEvent
from game.systems.game_mode.survival_mode import SpawnBudgetData, SurvivalMode
from game.world import GameWorld
from proto.generated import game_pb2
from protocol.codec import ProtocolCodec
from transport.connection_registry import ConnectionContext, ConnectionRegistry
from transport.game_proto_projector import GameProtoProjector
from transport.game_protocol_adapter import GameProtocolAdapter
from transport.outbound_queue import OutBoundQueue


class LevelDebugTests(unittest.TestCase):
    """覆盖对象误传、浮点数投影和调试消息阻断世界帧的回归。"""

    def make_world(self):
        """创建并启动真实生存模式，避免依赖正在运行的房间。"""
        mode = SurvivalMode()
        world = GameWorld(current_game_mode=mode)
        mode.start(world)
        return world, mode

    def test_debug_snapshot_copies_budget_amount(self):
        world, mode = self.make_world()
        budget = SpawnBudgetData(budget=12.75, budget_weight=1.0)
        mode._enemy_budget = {"enemy_slime": budget}

        debug = world._debug_data(1.0 / 30.0)[0]
        self.assertEqual(debug.enemy_budget[0].budget, 12.75)
        budget.budget = 99.0
        self.assertEqual(debug.enemy_budget[0].budget, 12.75)

    def test_fractional_debug_values_encode_with_integer_protocol(self):
        debug = LevelDebugEvent(
            enemy_budget=[EnemyBudgetData(enemy_type="enemy_slime", budget=12.75)],
            server_tick=307,
            cur_stage_id=1,
            stage_time_seconds=10.9,
            spwan_time_count_down_ms=987.9,
        )
        body = GameProtoProjector.level_debug(debug)
        raw = ProtocolCodec.get().encode_server("level_debug_data", body, server_tick=307)
        decoded = game_pb2.ServerMessage.FromString(raw)

        self.assertEqual(decoded.WhichOneof("payload"), "level_debug_data")
        self.assertEqual(decoded.server_tick, 307)
        self.assertEqual(decoded.level_debug_data.enemy_budget_data[0].budget, 12)
        self.assertEqual(decoded.level_debug_data.stage_time_seconds, 10)
        self.assertEqual(decoded.level_debug_data.spwan_time_count_down_ms, 987)
        self.assertEqual(debug.enemy_budget[0].budget, 12.75)

    def test_expired_countdown_encodes_as_zero(self):
        for remaining in (-33.3, -0.1, 0.0):
            with self.subTest(remaining=remaining):
                debug = LevelDebugEvent(spwan_time_count_down_ms=remaining)
                body = GameProtoProjector.level_debug(debug)
                decoded = game_pb2.LevelDebugData.FromString(body.SerializeToString())
                self.assertEqual(decoded.spwan_time_count_down_ms, 0)

    def test_stage_time_advances_with_gameplay_not_wall_clock(self):
        """阶段秒数跟随玩法推进，系统时间变化不会改变已用时长。"""
        with patch("time.time", return_value=1_700_000_000.0) as wall_clock:
            world, _ = self.make_world()
            self.assertEqual(world._debug_data(0.0)[0].stage_time_seconds, 0)
            wall_clock.return_value += 2.5
            result = world.step(2.5)
            debug = next(item for item in result.events if isinstance(item, LevelDebugEvent))
            self.assertEqual(debug.stage_time_seconds, 2)

            wall_clock.return_value += 3600.0
            self.assertEqual(world._debug_data(0.0)[0].stage_time_seconds, 2)
            body = GameProtoProjector.level_debug(debug)
            decoded = game_pb2.LevelDebugData.FromString(body.SerializeToString())
            self.assertEqual(decoded.stage_time_seconds, 2)
            self.assertIn("stage_time_seconds: 2", str(decoded))

    def test_stage_time_freezes_during_pause(self):
        """暂停期间世界仍推进，恢复后阶段计时只累计玩法时间。"""
        with patch("time.time", return_value=1_700_000_000.0) as wall_clock:
            world, mode = self.make_world()
            world.step(1.25)
            mode.pause_gameplay()
            wall_clock.return_value += 31.25
            paused = world.step(30.0)
            self.assertFalse(any(isinstance(item, LevelDebugEvent) for item in paused.events))
            mode.resume_gameplay()
            self.assertEqual(world._debug_data(0.0)[0].stage_time_seconds, 1)
            world.step(0.75)
            self.assertEqual(world._debug_data(0.0)[0].stage_time_seconds, 2)

    def test_stage_time_restarts_on_stage_change(self):
        """真实阶段到期后从零计时，下一阶段继续正常增长。"""
        with patch("time.time", return_value=1_700_000_000.0) as wall_clock:
            world, mode = self.make_world()
            previous_stage_id = mode._cur_stage.stage_id
            duration = mode._cur_stage.duration_seconds
            wall_clock.return_value += duration
            result = world.step(duration)
            debug = next(item for item in result.events if isinstance(item, LevelDebugEvent))
            self.assertEqual(debug.cur_stage_id, previous_stage_id + 1)
            self.assertEqual(debug.stage_time_seconds, 0)
            wall_clock.return_value += 2.25
            world.step(2.25)
            self.assertEqual(world._debug_data(0.0)[0].stage_time_seconds, 2)

    def test_360_ticks_publish_debug_and_world_frame_to_room(self):
        world, _ = self.make_world()
        registry = ConnectionRegistry.get()
        outbound = OutBoundQueue.get()
        queue = asyncio.Queue()
        connections = {
            1: ConnectionContext(1, None, room_id=world.room_id),
            2: ConnectionContext(2, None, room_id=world.room_id),
            3: ConnectionContext(3, None, room_id="another-room"),
        }

        with patch.object(registry, "connection_by_id", connections), patch.object(outbound, "queue", queue):
            adapter = GameProtocolAdapter(world)
            for tick in range(1, 361):
                result = world.step(1.0 / 30.0)
                if tick == 360:
                    # 在同一帧加入普通世界事件，确认调试发布不阻断正常同步。
                    result.events.append(EntityMovedEvent(entity_id="probe-player", x=10.0))
                adapter.publish_tick_result(result)
                debug_count = 0
                world_frame_count = 0
                while not queue.empty():
                    packet = queue.get_nowait()
                    self.assertEqual(set(packet.recipient_ids), {1, 2})
                    message = game_pb2.ServerMessage.FromString(packet.payload)
                    self.assertEqual(message.server_tick, tick)
                    if message.WhichOneof("payload") == "level_debug_data":
                        debug_count += 1
                        self.assertGreater(len(message.level_debug_data.enemy_budget_data), 0)
                    elif message.WhichOneof("payload") == "world_frame":
                        world_frame_count += 1
                        self.assertEqual(message.world_frame.movements[0].entity_id, "probe-player")
                self.assertEqual(debug_count, 1)
                self.assertEqual(world_frame_count, 1 if tick == 360 else 0)


if __name__ == "__main__":
    unittest.main()
