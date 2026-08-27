# coding=utf-8
"""战斗组件。"""

from dataclasses import dataclass
from game.model.components import Component


@dataclass(frozen=True)
class CombatComponent(Component):
    """战斗组件。"""
    hp: int = 100
    max_hp: int = 100
    attack: int = 10
    defense: int = 10