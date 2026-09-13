# coding=utf-8
"""生存、奖励、怪物表现配置及协议身份字段的回归验收。"""

from copy import deepcopy
from pathlib import Path
import io
import os
import subprocess
import sys
import unittest
from unittest.mock import patch

from game.model import config_loader as loader
from game.model.balance_config import build_reward_config, build_survival_config
from game.events import EntitySnapshot
from transport.game_proto_projector import GameProtoProjector
from proto.generated import game_pb2


class BalanceConfigTests(unittest.TestCase):
    """验证配置故障会阻止使用错误规则，调用方不会污染新表缓存。"""

    def setUp(self):
        self.reward = deepcopy(loader._REWARD_CONFIG_RAW)
        self.survival = deepcopy(loader._SURVIVAL_CONFIG_RAW)
        self.entities = set(loader._ENTITY_CAPABILITY_MAP)

    def build_survival(self):
        return build_survival_config(self.survival, loader.get_reward_config(), self.entities, set(loader.get_all_attack_configs()))

    def test_current_balance_contract(self):
        """八阶段共 780 秒，七种奖励定义，经验阈值合计 600。"""
        self.assertEqual(780, loader.get_survival_config().duration_seconds)
        self.assertEqual(600, sum(loader.get_reward_config().progression["next_level_xp"]))
        self.assertEqual(7, len(loader.get_reward_config().rewards))
        self.assertEqual("enemy_boss", loader.get_survival_stage(8).entry_spawn["enemy_type"])
        self.assertEqual((120, 300, 480), tuple(e["at_combat_seconds"] for e in loader.get_survival_config().timed_spawns))

    def test_nested_copies_are_isolated(self):
        """修改返回的嵌套配置，不会改变下一次读取结果。"""
        loader.get_reward_config().progression["next_level_xp"][0] = 999
        loader.get_survival_config().timed_spawns[0]["at_combat_seconds"] = 999
        loader.get_survival_stage(8).entry_spawn["enemy_type"] = "invalid"
        loader.get_entity_visual_config("enemy_slime")["sprite_sheet"] = "invalid"
        self.assertEqual(12, loader.get_reward_config().progression["next_level_xp"][0])
        self.assertEqual(120, loader.get_survival_config().timed_spawns[0]["at_combat_seconds"])
        self.assertEqual("enemy_boss", loader.get_survival_stage(8).entry_spawn["enemy_type"])
        self.assertTrue(loader.get_entity_visual_config("enemy_slime")["sprite_sheet"].endswith("slime.png"))

    def test_invalid_lookup_is_explicit(self):
        for stage in (0, 9, -1, True):
            with self.subTest(stage=stage), self.assertRaises(KeyError):
                loader.get_survival_stage(stage)
        with self.assertRaises(KeyError):
            loader.get_reward_definition("typo")

    def test_invalid_reward_effect_and_reference(self):
        self.reward["rewards"]["attack_up"]["effects"][0]["operation"] = "multiply_forever"
        with self.assertRaisesRegex(ValueError, "attack_up.effects"):
            build_reward_config(self.reward, self.entities)
        self.reward = deepcopy(loader._REWARD_CONFIG_RAW)
        self.reward["choice"]["pool"].append("typo")
        with self.assertRaisesRegex(ValueError, "choice.pool"):
            build_reward_config(self.reward, self.entities)

    def test_invalid_thresholds(self):
        self.reward["progression"]["next_level_xp"].pop()
        with self.assertRaisesRegex(ValueError, "next_level_xp"):
            build_reward_config(self.reward, self.entities)

    def test_invalid_pool_weights_or_special_type(self):
        self.survival["stages"][0]["pool"][0]["budget_share"] = 0.5
        with self.assertRaisesRegex(ValueError, "pool"):
            self.build_survival()
        self.survival["stages"][0]["pool"][0].update(enemy_type="enemy_elite", budget_share=1)
        with self.assertRaisesRegex(ValueError, "普通池"):
            self.build_survival()

    def test_invalid_stage_and_event_order(self):
        self.survival["stages"][1]["stage_id"] = 1
        with self.assertRaisesRegex(ValueError, "阶段编号"):
            self.build_survival()
        self.survival = deepcopy(loader._SURVIVAL_CONFIG_RAW)
        self.survival["timed_spawns"][1]["at_combat_seconds"] = 100
        with self.assertRaisesRegex(ValueError, "按时间排列"):
            self.build_survival()

    def test_boss_cannot_receive_stage_scaling(self):
        self.survival["enemies"]["enemy_boss"]["apply_stage_scaling"] = True
        with self.assertRaisesRegex(ValueError, "首领"):
            self.build_survival()

    def test_json_rejects_duplicates_nonfinite_and_nonobject(self):
        """注入文件内容验证实际解析入口，不改动正式配置。"""
        for content in ('{"a": 1, "a": 2}', '{"a": NaN}', '{"a": 1e999}', '[]', '{"nested": {"a": 1, "a": 2}}', '{"a":}'):
            with self.subTest(content=content), patch.object(Path, "open", return_value=io.StringIO(content)), self.assertRaises(ValueError):
                loader._load_json("bad.json")

    def test_import_is_independent_of_working_directory(self):
        environment = dict(os.environ, PYTHONPATH=str(loader._SERVER_DIR), PYTHONDONTWRITEBYTECODE="1")
        result = subprocess.run([sys.executable, "-B", "-c", "from game.model.config_loader import get_survival_config; print(get_survival_config().duration_seconds)"], cwd=loader._SERVER_DIR.parent / "client", env=environment, capture_output=True, text=True, timeout=20)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual("780", result.stdout.strip())

    def test_monster_assets_and_attack_timing(self):
        """五种怪物资源存在，AI 引用和各段攻击绝对时间一致。"""
        client = loader._SERVER_DIR.parent / "client"
        for enemy_key in loader.get_survival_config().enemies:
            visual = loader.get_entity_visual_config(enemy_key)
            self.assertTrue((client / visual["sprite_sheet"].removeprefix("res://")).is_file())
            self.assertEqual((8, 10), (visual["columns"], visual["rows"]))
            capability = loader.get_capability(enemy_key)
            ai = loader.get_entity_ai_config(capability.ai_id)
            attack = loader.get_attack_config(ai.attack_id)
            self.assertIsNotNone(attack)
            self.assertGreaterEqual(ai.attack_interval_ms, max(attack.colldown_ms, attack.get_attack_time()))
        for attack in loader.get_all_attack_configs().values():
            previous = 0
            for shape in attack.shape_list:
                self.assertLessEqual(previous, shape.hit_time)
                self.assertLess(shape.hit_time, shape.duration)
                previous = shape.duration

    def test_monster_template_survives_protocol_round_trip(self):
        for enemy_key in loader.get_survival_config().enemies:
            snapshot = EntitySnapshot(entity_id="test_" + enemy_key, entity_type=2, entity_config_key=enemy_key)
            message = GameProtoProjector.entity_info(snapshot)
            decoded = game_pb2.EntityInfo.FromString(message.SerializeToString())
            self.assertEqual(enemy_key, decoded.entity_config_key)

    def test_config_mirrors_match_source(self):
        root = loader._SERVER_DIR.parent
        for source in (root / "json_config").glob("*.json"):
            for destination in (root / "server/config", root / "client/config"):
                self.assertEqual(source.read_bytes(), (destination / source.name).read_bytes(), str(destination / source.name))


if __name__ == "__main__":
    unittest.main()
