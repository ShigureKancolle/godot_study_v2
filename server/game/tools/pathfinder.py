# coding=utf-8

import game.model.navigation_grid as navigation_grid
import heapq
from typing import List, Tuple
import math


DIAGONAL_COST: float = math.sqrt(2.0)
_DIRECTIONS: List[Tuple[int, int, bool]] = [
    (0, -1, False),   # 上
    (0, 1, False),    # 下
    (-1, 0, False),   # 左
    (1, 0, False),    # 右
    (-1, -1, True),   # 左上
    (1, -1, True),    # 右上
    (-1, 1, True),    # 左下
    (1, 1, True),     # 右下
]

class PathFinder:
    '''路径查找器'''
    def __init__(self, map_id: str):
        self.map_id = map_id

    def find_path(self, start_pos: tuple[float, float], end_pos: tuple[float, float], search_radius: float = 500.0):
        # 这里有没有什么方便的切换多种寻路的办法？
        path = self._find_path_by_astar(start_pos, end_pos, search_radius)
        return path

    def _get_block_data_by_world_pos(self, x: float, y: float) -> navigation_grid.BlockData:
        '''获取指定位置的块数据'''
        # 如果是用公式生成的 应该要用公式计算获取信息
        return navigation_grid.get_block_data_by_world_pos(x, y, self.map_id)

    def is_walkable(self, x: float, y: float) -> bool:
        '''检查指定位置是否可走'''
        _x, _y = self._world_pos_to_block(x, y)
        return self._is_walkable(_x, _y)
        

    def _is_walkable(self, x: int, y: int) -> bool:
        '''检查指定位置是否可走'''
        block_data = self._get_block_data_by_block_pos(x, y)
        if block_data is None:
            return False
        # 可以根据地块类型来增加代价
        return block_data.terrain_type != 4

    def _get_block_data_by_block_pos(self, x: int, y: int) -> navigation_grid.BlockData:
        '''获取指定位置的块数据'''
        data = navigation_grid.get_block_data(x, y, self.map_id)
        if data is None:
            return None
        return data

    # ======================================================================
    # astar 寻路算法
    # ======================================================================
    def _find_path_by_astar(self, start_pos: tuple[float, float], end_pos: tuple[float, float], search_radius: float = 500.0):
        '''使用 astar 寻路算法查找路径'''
        # todo 检查搜索半径是否超出地图范围
        if (end_pos[0] - start_pos[0])**2 + (end_pos[1] - start_pos[1])**2 > search_radius**2:
            return None

        # 转换为块坐标
        start_block = self._world_pos_to_block(start_pos[0], start_pos[1])
        end_block = self._world_pos_to_block(end_pos[0], end_pos[1])

        # todo 检查起点和终点是否超出地图范围 或者不可达
        if not self._is_walkable(start_block[0], start_block[1]):
            return None
        if not self._is_walkable(end_block[0], end_block[1]):
            return None

        # 真实代价
        g_map: dict[tuple[int, int], float] = {start_block: 0}

        # 父节点
        parent_map: dict[tuple[int, int], tuple[int, int]] = {}

        # 待访问节点
        # todo_list = [(f, x, y)]
        todo_list: list[tuple[float, int, int]] = []
        heapq.heappush(todo_list, (0, start_block[0], start_block[1]))

        while(todo_list):
            f, x, y = heapq.heappop(todo_list)
            if (x, y) == end_block:
                return self._reconstruct_path(parent_map, (x, y))

            for dx, dy, is_diagonal in _DIRECTIONS:
                new_x = x + dx
                new_y = y + dy
                if not self._is_walkable(new_x, new_y):
                    # 不能走就跳过
                    continue

                # 从上格走到这格的实际代价
                new_g_score = g_map[(x, y)] + (DIAGONAL_COST if is_diagonal else 1.0)
                if new_g_score < g_map.get((new_x, new_y), float('inf')):
                    g_map[(new_x, new_y)] = new_g_score
                    parent_map[(new_x, new_y)] = (x, y)
                    # 加上方向修正 预估到达终点的代价
                    f_score = new_g_score + self._get_heuristic((new_x, new_y), end_block)
                    heapq.heappush(todo_list, (f_score, new_x, new_y))

        # 所有能走的格子都没了 说明没有路径
        return None

    def _get_heuristic(self, pos: tuple[int, int], end_pos: tuple[int, int]) -> float:
        """
        A* 启发式函数:估计从 tile 到 goal 的代价。

        用「对角线距离」(octile distance),适合 8 方向移动:
            h = max(dx, dy) + (sqrt(2)-1) * min(dx, dy)
        其中 dx, dy 是两个轴的距离。

        这个启发式是 admissible(不高估)且 consistent(单调),
        保证 A* 找到最优路径。
        """
        dx = abs(pos[0] - end_pos[0])
        dy = abs(pos[1] - end_pos[1])
        return float(max(dx, dy)) + (DIAGONAL_COST - 1.0) * float(min(dx, dy))
            

    def _reconstruct_path(self, parent_map: dict[tuple[int, int], tuple[int, int]], end_pos: tuple[int, int]) -> list[tuple[int, int]]:
        '''重建路径'''
        path = []
        current = end_pos
        while current in parent_map:
            # 转换为块的中心坐标
            world_pos = self._block_center_to_world_pos(current[0], current[1])
            path.append(world_pos)
            current = parent_map[current]
        path.reverse()
        return path


    def _world_pos_to_block_center(self, x: float, y: float) -> tuple[float, float]:
        '''将世界坐标转换为块中心坐标'''
        return navigation_grid.world_pos_to_block_center(x, y, self.map_id)

    def _world_pos_to_block(self, x: float, y: float) -> tuple[int, int]:
        '''将世界坐标转换为块坐标'''
        return navigation_grid.world_pos_to_block(x, y, self.map_id)

    def _block_center_to_world_pos(self, x: float, y: float) -> tuple[float, float]:
        '''将块的中心坐标转换为世界坐标'''
        return navigation_grid.block_center_to_world_pos(x, y, self.map_id)
