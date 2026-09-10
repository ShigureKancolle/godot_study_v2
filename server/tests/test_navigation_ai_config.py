# coding=utf-8
"""导航 AI 配置读取回归测试。"""

import unittest

from game.model import config_loader


class NavigationAiConfigTests(unittest.TestCase):
    """验证 navigation 全局区不会与实体 AI 配置混淆。"""

    def test_loads_navigation_values(self):
        """公共 JSON 中的四个寻路调度参数应按整数读取。"""
        navigation = config_loader.get_navigation_ai_config()

        self.assertEqual(500, navigation.min_path_hold_ms)
        self.assertEqual(2, navigation.target_repath_distance_blocks)
        self.assertEqual(1000, navigation.unreachable_retry_ms)
        self.assertEqual(150, navigation.repath_jitter_ms)

    def test_navigation_is_not_an_entity_ai_config(self):
        """navigation 顶层键不应进入按实体名称建立的配置表。"""
        self.assertNotIn("navigation", config_loader._ENTITY_AI_CONFIG_MAP)
        self.assertIn("slime_ai_001", config_loader._ENTITY_AI_CONFIG_MAP)
        self.assertIn("skeleton_ai_001", config_loader._ENTITY_AI_CONFIG_MAP)

    def test_missing_fields_use_documented_defaults(self):
        """缺失字段时使用与正式配置一致的安全默认值。"""
        navigation = config_loader._build_navigation_ai_config({})

        self.assertEqual(config_loader.NavigationAiConfig(), navigation)


if __name__ == "__main__":
    unittest.main()
