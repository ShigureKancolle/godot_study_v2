# coding=utf-8
"""战斗组件。"""

from dataclasses import dataclass
from game.model.components import Component


@dataclass
class CombatComponent(Component):
    """战斗组件。"""
    hp: int = 100
    max_hp: int = 100
    attack: int = 10
    defense: int = 10
    is_dead: bool = False
    atk_facing: float = 0.0

    atk_facing_locking: bool = False

    def load_combat_config(self, combat_type: int):
        print(f"加载战斗配置，类型: {combat_type}")
