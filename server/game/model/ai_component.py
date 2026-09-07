# coding=utf-8
"""AI组件。"""

from dataclasses import dataclass, field
from game.model.components import Component

class AIComponent(Component):
    """AI组件。"""
    state: str = "idle"
    config_name: str = "slime_ai_001"
