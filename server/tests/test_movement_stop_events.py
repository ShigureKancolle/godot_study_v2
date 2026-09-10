# coding=utf-8
"""验证死亡、锁定后的停止事件能够完整同步给客户端。"""

import unittest

from game.commands import MoveCommand
from game.events import CommandRejectedEvent, EntityMovedEvent
from game.model.combat_component import CombatComponent
from game.model.components import FacingComponent, MovementComponent, TransformComponent
from game.world import GameWorld
from proto.generated import game_pb2
from transport.game_protocol_adapter import GameProtocolAdapter
from transport.outbound_queue import OutBoundQueue
from transport.world_frame_build import WorldFrameBuilder


class MovementStopEventTests(unittest.TestCase):
    """通过真实世界更新和协议编码检查停止事件。"""

    dt = 1.0 / 30.0

    def test_dead_chasing_enemy_publishes_stop_and_generates_no_ai_commands(self):
        world = GameWorld()
        player = world.create_player("stop-test")
        player.get_component(TransformComponent).x = 200.0
        enemy = world.create_enemy("enemy_slime", 0.0, 0.0)
        world.step(self.dt)
        movement = enemy.get_component(MovementComponent)
        self.assertTrue(movement.moving)
        facing_before = (movement.dir_x, movement.dir_y)
        position_before = enemy.get_component(TransformComponent).x

        combat = enemy.get_component(CombatComponent)
        combat.hp = 0
        combat.is_dead = True
        with self.assertNoLogs("game.systems.ai_compsystem", level="ERROR"):
            result = world.step(self.dt)

        self.assertEqual([], world._ai_comp_system.get_ai_commands())
        self.assertEqual(position_before, enemy.get_component(TransformComponent).x)
        self.assertFalse(movement.moving)
        stopped = self._get_stop(result, enemy.entity_id)
        self.assertEqual(facing_before, stopped.facing)

        # 只隔离出站队列，实际执行发布、世界帧构造和协议编码。
        adapter = GameProtocolAdapter(world)
        outbound = OutBoundQueue.get()
        while not outbound.queue.empty():
            outbound.queue.get_nowait()
        self.addCleanup(self._clear_outbound)
        adapter.publish_tick_result(result)
        packet = outbound.queue.get_nowait()
        message = game_pb2.ServerMessage.FromString(packet.payload)
        self.assertEqual("world_frame", message.WhichOneof("payload"))
        entry = next(item for item in message.world_frame.movements if item.entity_id == enemy.entity_id)
        self.assertFalse(entry.moving)
        self.assertEqual(facing_before, (entry.facing_x, entry.facing_y))
        self.assertTrue(any(item.entity_dead.entity_id == enemy.entity_id for item in message.world_frame.events))

        with self.assertNoLogs("game.systems.ai_compsystem", level="ERROR"):
            next_tick = world.step(self.dt)
        self.assertFalse(any(isinstance(item, EntityMovedEvent) for item in next_tick.events))

    def test_death_or_lock_still_publishes_stop_after_rejecting_queued_move(self):
        for reason in ("dead", "locked"):
            with self.subTest(reason=reason):
                world = GameWorld()
                player = world.create_player("queued-stop")
                world.enqueue_command(MoveCommand(entity_id=player.entity_id, dir_y=1.0, moving=True))
                world.step(self.dt)
                transform = player.get_component(TransformComponent)
                position_before = (transform.x, transform.y)
                facing_before = player.get_component(FacingComponent).facing
                if reason == "dead":
                    player.get_component(CombatComponent).is_dead = True
                else:
                    player.get_component(MovementComponent).is_locked = True

                # 上一轮发出的移动请求在实体死亡或锁定后才被处理。
                world.enqueue_command(MoveCommand(entity_id=player.entity_id, dir_x=1.0, moving=True))
                result = world.step(self.dt)
                self.assertTrue(any(isinstance(item, CommandRejectedEvent) for item in result.events))
                self.assertEqual(position_before, (transform.x, transform.y))
                stopped = self._get_stop(result, player.entity_id)
                self.assertEqual(facing_before, stopped.facing)
                builder = WorldFrameBuilder(result.server_tick)
                for item in result.events:
                    builder.apply(item)
                frame = builder.build()
                self.assertEqual(1, len(frame.movements))
                self.assertFalse(frame.movements[0].moving)
                frame.SerializeToString()

    def test_default_movement_event_has_serializable_facing(self):
        builder = WorldFrameBuilder(1)
        builder.apply(EntityMovedEvent(entity_id="stopped", moving=False, anim_state="idle"))
        entry = builder.build().movements[0]
        self.assertEqual((0.0, 0.0), (entry.facing_x, entry.facing_y))

    def _get_stop(self, result, entity_id):
        stopped = [item for item in result.events if isinstance(item, EntityMovedEvent) and item.entity_id == entity_id]
        self.assertEqual(1, len(stopped))
        self.assertFalse(stopped[0].moving)
        self.assertEqual("idle", stopped[0].anim_state)
        return stopped[0]

    @staticmethod
    def _clear_outbound():
        outbound = OutBoundQueue.get()
        while not outbound.queue.empty():
            outbound.queue.get_nowait()


if __name__ == "__main__":
    unittest.main()
