# coding=utf-8
"""死亡延迟移除的回归测试。"""

import unittest

from game.events import EntityDiedEvent, EntityRemovedEvent
from game.model.combat_component import CombatComponent
from game.world import GameWorld


class DeathSystemTests(unittest.TestCase):
    """验证死亡事件、延迟保留和到期移除顺序。"""

    def test_dead_entity_is_removed_after_configured_delay(self):
        world = GameWorld()
        enemy = world.create_enemy("enemy_slime", 0.0, 0.0)
        combat = enemy.get_component(CombatComponent)
        combat.hp = 0
        combat.is_dead = True

        first_tick = world.step(0.1)

        self.assertIs(world.get_entity(enemy.entity_id), enemy)
        self.assertTrue(any(isinstance(item, EntityDiedEvent) for item in first_tick.events))
        self.assertFalse(any(isinstance(item, EntityRemovedEvent) for item in first_tick.events))

        middle_tick = world.step(0.5)

        self.assertIs(world.get_entity(enemy.entity_id), enemy)
        self.assertFalse(any(isinstance(item, EntityRemovedEvent) for item in middle_tick.events))

        final_tick = world.step(0.2)

        self.assertIsNone(world.get_entity(enemy.entity_id))
        self.assertTrue(any(isinstance(item, EntityRemovedEvent) for item in final_tick.events))


if __name__ == "__main__":
    unittest.main()
