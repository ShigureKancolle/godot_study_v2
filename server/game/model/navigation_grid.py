# coding=utf-8
'''固定的地图数据'''

from dataclasses import dataclass, field
from game.model.config_loader import get_navigation_map

TEST_MAP_ID = "navigation_test_map"

@dataclass
class BlockData:
    '''导航地图中的一个块'''
    terrain_type: int = 0 # 地块类型 0草 1沙 2泥 3地砖      4水 不可走
    center_pos: tuple[int, int] = (0, 0) # 块的中心坐标 用来当作寻路的节点坐标

def get_block_data(block_x: int, block_y: int, map_id=TEST_MAP_ID):
    navigation_map = get_navigation_map(map_id)
    if block_x < navigation_map.block_bounds_start[0] or \
        block_x >= navigation_map.block_bounds_end[0] or \
        block_y < navigation_map.block_bounds_start[1] or \
        block_y >= navigation_map.block_bounds_end[1]:
        return None
    block_x_num = navigation_map.block_bounds_end[0] - navigation_map.block_bounds_start[0]
    block_y_num = navigation_map.block_bounds_end[1] - navigation_map.block_bounds_start[1]
    terrain_idx = (block_y + block_y_num // 2) * block_x_num + (block_x + block_x_num // 2)
    if terrain_idx < 0 or terrain_idx >= len(navigation_map.terrain_ids):
        return None
    cell_size_px = navigation_map.tile_size_px
    block_size = navigation_map.block_size
    block_size_px = (block_size[0] * cell_size_px[0], block_size[1] * cell_size_px[1])
    data = BlockData(
        terrain_type=navigation_map.terrain_ids[terrain_idx],
        center_pos=(block_x * block_size_px[0] + cell_size_px[0], block_y * block_size_px[1] + cell_size_px[1]),
    )
    return data

def get_block_data_by_world_pos(x: float, y: float, map_id=TEST_MAP_ID):
    '''
    根据世界坐标获取块数据
    x, y = 0, 0 时，返回 (0, 0) 对应的块数据
    x, y = 100, 100 时，返回 (100 // block_size_px, 100 // block_size_px) 对应的块数据
    '''

    block_x, block_y = world_pos_to_block(x, y, map_id=map_id)
    return get_block_data(block_x, block_y, map_id=map_id)


def world_pos_to_block_center(x: float, y: float, map_id=TEST_MAP_ID):
    '''
    将世界坐标转换为块中心坐标
    '''
    block_size = get_navigation_map(map_id).block_size
    cell_size_px = get_navigation_map(map_id).tile_size_px
    block_size_px = (block_size[0] * cell_size_px[0], block_size[1] * cell_size_px[1])
    block_x = int(x // block_size_px[0])
    block_y = int(y // block_size_px[1])
    return (block_x * block_size_px[0] + cell_size_px[0], block_y * block_size_px[1] + cell_size_px[1])


def world_pos_to_block(x: float, y: float, map_id=TEST_MAP_ID):
    '''
    将世界坐标转换为块坐标   
    '''
    block_size = get_navigation_map(map_id).block_size
    cell_size_px = get_navigation_map(map_id).tile_size_px
    block_size_px = (block_size[0] * cell_size_px[0], block_size[1] * cell_size_px[1])
    block_x = int(x // block_size_px[0])
    block_y = int(y // block_size_px[1])
    return (block_x, block_y)

def block_center_to_world_pos(x: float, y: float, map_id=TEST_MAP_ID):
    '''
    将块中心坐标转换为世界坐标
    x, y = 0, 0 时，返回 (16, 16)
    x, y = 100, 100 时，返回 (100 * block_size_px + 16, 100 * block_size_px + 16)
   
    '''

    block_size = get_navigation_map(map_id).block_size
    cell_size_px = get_navigation_map(map_id).tile_size_px
    block_size_px = (block_size[0] * cell_size_px[0], block_size[1] * cell_size_px[1])
    return (x*block_size_px[0] + cell_size_px[0], y*block_size_px[1] + cell_size_px[1])