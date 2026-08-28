# coding=utf-8
"""战斗组件。"""

from dataclasses import dataclass, field
import logging
from game.model.components import Component


logger = logging.getLogger(__name__)

@dataclass
class PendingAttack:
    attacker_id: str
    attack_id: int
    atk_facing: float
    elapsed_ms: float = 0.0
    fired_shape_indexes: set[int] = field(default_factory=set)

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
        logger.debug("加载战斗配置：combat_type=%s", combat_type)
