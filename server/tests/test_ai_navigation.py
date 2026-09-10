# coding=utf-8
"""验证 AI 路径重算条件和无路重试间隔。"""

import unittest

from game.model import navigation_grid
from game.model.ai_component import AIComponent
from game.model.components import TransformComponent
from game.model.navigation_component import NavigationComponent
from game.world import GameWorld


class RecordingPathFinder:
    """记录寻路次数，并按顺序返回测试预设结果。"""

    def __init__(self, results):
        self.results = list(results)
        self.calls = []

    def find_path(self, start_pos, end_pos, search_radius):
        self.calls.append((start_pos, end_pos, search_radius))
        if not self.results:
            raise AssertionError("测试没有为本次寻路准备返回值")
        return self.results.pop(0)


class AINavigationTests(unittest.TestCase):
    """通过真实 AI 决策入口检查导航状态。"""

    dt = 1.0 / 30.0

    def test_repaths_when_target_block_changes_cancel_in_coordinate_sum(self):
        """横纵变化互相抵消时也应按二维距离重新寻路。"""
        world, player, enemy = self._make_chasing_world()
        navigation = enemy.get_component(NavigationComponent)
        target = player.get_component(TransformComponent)
        target.x, target.y = navigation_grid.block_center_to_world_pos(3, -3, world.map_id)
        expected_path = [navigation_grid.block_center_to_world_pos(1, -1, world.map_id)]
        recorder = RecordingPathFinder([expected_path])
        world.pathfinder = recorder

        world._ai_comp_system.decide(world, self.dt)

        self.assertEqual(1, len(recorder.calls))
        self.assertEqual((3, -3), navigation.planned_target_block)
        self.assertEqual(expected_path, navigation.path)

    def test_does_not_repath_while_target_remains_in_same_block(self):
        """目标在原 block 内移动时继续使用已有路径。"""
        world, player, enemy = self._make_chasing_world()
        target = player.get_component(TransformComponent)
        target.x = 24.0
        target.y = 24.0
        recorder = RecordingPathFinder([])
        world.pathfinder = recorder

        world._ai_comp_system.decide(world, self.dt)

        self.assertEqual([], recorder.calls)

    def test_unreachable_target_waits_until_retry_tick(self):
        """无路结果在间隔内不重复查询，到期后再查询。"""
        world, _player, enemy = self._make_chasing_world(with_existing_path=False)
        recorder = RecordingPathFinder([None, None])
        world.pathfinder = recorder
        navigation = enemy.get_component(NavigationComponent)

        world._ai_comp_system.decide(world, self.dt)
        retry_tick = navigation.unreachable_retry_tick
        self.assertGreater(retry_tick, world.cur_tick())
        self.assertEqual(1, len(recorder.calls))

        world._tick = retry_tick - 1
        world._ai_comp_system.decide(world, self.dt)
        self.assertEqual(1, len(recorder.calls))

        world._tick = retry_tick
        world._ai_comp_system.decide(world, self.dt)
        self.assertEqual(2, len(recorder.calls))
        self.assertGreater(navigation.unreachable_retry_tick, retry_tick)

    def test_target_change_ignores_previous_unreachable_retry_tick(self):
        """换目标后应立即查询，不沿用旧目标的无路等待。"""
        world, _player, enemy = self._make_chasing_world(with_existing_path=False)
        recorder = RecordingPathFinder([None, None])
        world.pathfinder = recorder
        navigation = enemy.get_component(NavigationComponent)
        ai = enemy.get_component(AIComponent)

        world._ai_comp_system.decide(world, self.dt)
        retry_tick = navigation.unreachable_retry_tick
        replacement = world.create_player("replacement")
        replacement_transform = replacement.get_component(TransformComponent)
        replacement_transform.x = 96.0
        replacement_transform.y = 0.0
        ai.state_target_id = replacement.entity_id

        self.assertLess(world.cur_tick(), retry_tick)
        world._ai_comp_system.decide(world, self.dt)

        self.assertEqual(2, len(recorder.calls))
        self.assertEqual(replacement.entity_id, navigation.planned_target_id)

    @staticmethod
    def _make_chasing_world(with_existing_path=True):
        """建立目标有效、不会进入攻击范围的追逐场景。"""
        world = GameWorld()
        player = world.create_player("target")
        player_transform = player.get_component(TransformComponent)
        player_transform.x = 80.0
        player_transform.y = 16.0

        enemy = world.create_enemy("enemy_slime", 16.0, 16.0)
        ai = enemy.get_component(AIComponent)
        ai.state = "chase"
        ai.state_target_id = player.entity_id

        navigation = enemy.get_component(NavigationComponent)
        navigation.planned_target_id = player.entity_id
        navigation.planned_target_block = (0, 0)
        navigation.repath_not_before_tick = 0
        if with_existing_path:
            navigation.path = [navigation_grid.block_center_to_world_pos(1, 0, world.map_id)]
        return world, player, enemy


if __name__ == "__main__":
    unittest.main()
