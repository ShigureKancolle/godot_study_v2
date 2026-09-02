# coding=utf-8
"""战斗组件。"""

from dataclasses import dataclass, field
import logging
from game.model.components import Component
import game.model.config_loader as config_loader


logger = logging.getLogger(__name__)

@dataclass
class HitBox:
    shape_type: config_loader.ShapeType = config_loader.ShapeType.CIRCLE
    local_offset: tuple[float, float] = (0.0, 0.0) # 相对Entity.position的偏移量
    radius: float = 0.0 # shape_type为CIRCLE时的半径

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

    def load_combat_config(self, combat_type: str):
        logger.debug("加载战斗配置：combat_type=%s", combat_type)
        combat_stats = config_loader.get_combat_stats(combat_type)
        self.max_hp = combat_stats.max_hp
        self.hp = self.max_hp
        self.defense = combat_stats.defense

