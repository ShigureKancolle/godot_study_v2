# coding=utf-8
"""进度组件。"""

from game.model import config_loader
from game.model.components import Component

import typing
if typing.TYPE_CHECKING:
    from game.model.entity import Entity


class ProgressionComponent(Component):
    """进度组件。"""
    total_exp: float = 0.0
    level: int = 1


