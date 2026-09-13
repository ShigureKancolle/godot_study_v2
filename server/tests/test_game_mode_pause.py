# coding=utf-8
"""验证游戏模式暂停对命令、系统更新和生命周期命令的影响。"""

import unittest

from game.commands import JoinCommand, LeaveCommand, MoveCommand, WorldCommand
from game.events import CommandRejectedEvent, EntityJoinedEvent, EntityRemovedEvent
from game.model.components import MovementComponent, TransformComponent
from game.systems.comp_system import CompSystem, MovementCompSystem
from game.systems.game_mode.game_mode import GameMode, SystemScope
from game.world import GameWorld


class AlwaysUpdateProbeSystem(CompSystem):
    """记录暂停期间始终更新的系统调用次数。"""

    def init(self):
        self.update_count = 0

    def apply_command(self, world, command):
        return []

    def update(self, world, dt):
        self.update_count += 1
        return []


class GameModePauseTests(unittest.TestCase):
    """暂停玩法时保持世界 tick 和生命周期命令可用。"""

    def setUp(self):
        self.mode = GameMode()
        self.world = GameWorld(current_game_mode=self.mode)
        self.player = self.world.create_player("pause-player")

    def test_gameplay_command_and_update_are_paused_then_resume(self):
        movement = self.player.get_component(MovementComponent)
        transform = self.player.get_component(TransformComponent)

        self.world.enqueue_command(MoveCommand(
            entity_id=self.player.entity_id,
            connection_id=31,
            dir_x=1.0,
            moving=True,
        ))
        self.world.step(1.0)
        position_before_pause = transform.x
        self.assertGreater(position_before_pause, 0.0)

        self.mode.pause_gameplay()
        self.world.enqueue_command(MoveCommand(
            entity_id=self.player.entity_id,
            connection_id=31,
            dir_y=1.0,
            moving=True,
        ))
        paused_result = self.world.step(1.0)

        self.assertEqual(position_before_pause, transform.x)
        self.assertEqual(0.0, transform.y)
        rejection = next(item for item in paused_result.events if isinstance(item, CommandRejectedEvent))
        self.assertEqual("GAMEPLAY_PAUSED", rejection.reason_code)
        self.assertEqual(31, rejection.connection_id)
        self.assertTrue(movement.moving)

        self.mode.resume_gameplay()
        self.world.step(1.0)
        self.assertGreater(transform.x, position_before_pause)

    def test_join_and_leave_commands_continue_while_paused(self):
        self.mode.pause_gameplay()
        self.world.enqueue_command(JoinCommand(
            connection_id=41,
            account="late-player",
            player_name="Late",
        ))
        join_result = self.world.step(1.0)

        joined = next(item for item in join_result.events if isinstance(item, EntityJoinedEvent))
        joined_entity_id = joined.entity_info.entity_id
        self.assertIsNotNone(self.world.get_entity(joined_entity_id))

        self.world.enqueue_command(LeaveCommand(
            entity_id=joined_entity_id,
            connection_id=41,
            account="late-player",
        ))
        leave_result = self.world.step(1.0)

        self.assertTrue(any(isinstance(item, EntityRemovedEvent) for item in leave_result.events))
        self.assertIsNone(self.world.get_entity(joined_entity_id))

    def test_ai_decision_and_movement_are_paused_then_resume(self):
        player_transform = self.player.get_component(TransformComponent)
        player_transform.x = 200.0
        enemy = self.world.create_enemy("enemy_slime", 0.0, 0.0)
        enemy_transform = enemy.get_component(TransformComponent)
        enemy_movement = enemy.get_component(MovementComponent)

        self.mode.pause_gameplay()
        self.world.step(1.0)

        self.assertEqual(0.0, enemy_transform.x)
        self.assertFalse(enemy_movement.moving)

        self.mode.resume_gameplay()
        self.world.step(1.0)

        self.assertGreater(enemy_transform.x, 0.0)
        self.assertTrue(enemy_movement.moving)

    def test_command_handler_and_update_share_one_system_instance(self):
        registered = self.world._system_instances[MovementCompSystem]
        handler_data = self.world._command_router._handlers[MoveCommand]
        pipeline_data = next(
            item for item in self.world._tick_pipeline._systems
            if isinstance(item.system, MovementCompSystem)
        )

        self.assertIs(registered, handler_data.handler.__self__)
        self.assertIs(registered, pipeline_data.system)

    def test_always_system_continues_updating_while_paused(self):
        probe = self.world.register_system(
            AlwaysUpdateProbeSystem,
            update_scope=SystemScope.ALWAYS,
        )

        self.mode.pause_gameplay()
        self.world.step(1.0)

        self.assertEqual(1, probe.update_count)

    def test_unregistered_command_returns_rejection(self):
        self.world.enqueue_command(WorldCommand(connection_id=51))

        result = self.world.step(1.0)

        rejection = next(item for item in result.events if isinstance(item, CommandRejectedEvent))
        self.assertEqual("COMMAND_NOT_REGISTERED", rejection.reason_code)
        self.assertEqual(51, rejection.connection_id)


if __name__ == "__main__":
    unittest.main()
