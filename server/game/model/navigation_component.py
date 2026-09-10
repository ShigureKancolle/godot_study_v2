# coding=utf-8
"""导航组件。"""

from game.model.components import Component
import logging
from dataclasses import dataclass, field

logger = logging.getLogger(__name__)

@dataclass
class NavigationComponent(Component):
    '''导航组件。'''

    # 如果地图可变 再启用
    # planned_map_version: int = 0
    
    
    path: list[tuple[float, float]] = field(default_factory=list)
    '''路径'''
    
    path_index: int = 0
    '''路径索引'''

    next_path_index: int = 0
    '''下一个路径索引'''

    path_index_loop: bool = False
    '''路径索引是否循环'''

    planned_target_id: str = ""
    '''目标实体ID'''

    planned_target_block: tuple[int, int] = (0, 0)
    '''当前路径目标实体所在地图块的坐标'''

    repath_not_before_tick: int = 0
    '''在第几tick后才能重新规划路径'''

    unreachable_retry_tick: int = 0
    '''目标不可到达时 在第几tick后才能重试'''

    def clear_path(self):
        self.path = []
        self.path_index = 0
        self.path_index_loop = False
        self.planned_target_id = ""
        self.planned_target_block = (0, 0)
        self.repath_not_before_tick = 0
        self.unreachable_retry_tick = 0
