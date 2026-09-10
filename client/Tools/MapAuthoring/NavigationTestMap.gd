@tool
extends TileMapLayer

## 文件：client/Tools/MapAuthoring/NavigationTestMap.gd
## 作用：为 NavigationTestMap.tscn 建立首版固定逻辑地图和带 terrain_id 的 TileSet。
##
## 这段脚本只属于编辑器制图源，不参与服务端移动或 A*。
## 第一次打开场景时，如果 Terrain 层为空，它会自动生成地图；生成后可直接用 TileMap
## 画笔继续修改并保存场景。需要恢复本文件定义的基准布局时，点击检查器里的“重建基准地图”。

# v1 公式规定 1 block = 2×2 tile；所有边界和池塘都按 block 对齐。
const BLOCK_SIZE: int = 2

# v1 使用 16×16 像素 tile；服务端以后只需读取 JSON 中的数值，不读取这张贴图。
const TILE_SIZE := Vector2i(16, 16)

# TileSet 只有一个 atlas source，固定使用 source_id=0，便于导出脚本严格校验。
const SOURCE_ID: int = 0

# atlas 左侧格是草地，坐标 (0,0)；右侧格是水，坐标 (1,0)。
const GRASS_ATLAS_COORD := Vector2i(0, 0)
const WATER_ATLAS_COORD := Vector2i(1, 0)

# terrain_id 与 json_config/terrain_config.json 的既有约定保持一致。
const TERRAIN_GRASS: int = 0
const TERRAIN_WATER: int = 4

# 总地图 block 范围：x=[-34,34)，y=[-22,22)，共 68×44 block。
# 换算成 tile 后是 136×88 tile，即 2176×1408 像素。
const MAP_BLOCK_MIN := Vector2i(-34, -22)
const MAP_BLOCK_MAX_EXCLUSIVE := Vector2i(34, 22)

# 可行动内部范围：x=[-32,32)，y=[-20,20)，共 64×40 block。
# 外层与总范围相差 2 block，所以四周水边界厚度严格为 2 block=4 tile。
const WALKABLE_BLOCK_MIN := Vector2i(-32, -20)
const WALKABLE_BLOCK_MAX_EXCLUSIVE := Vector2i(32, 20)

# 三个内部池塘也全部按 block 描述，Rect2i 的 size 同样以 block 为单位。
# 不同长宽和位置可测试短绕行、长边绕行以及连续拐弯路径。
const POND_BLOCK_RECTS := [
	Rect2i(Vector2i(-23, -10), Vector2i(7, 6)),
	Rect2i(Vector2i(5, -11), Vector2i(9, 4)),
	Rect2i(Vector2i(-4, 4), Vector2i(7, 8)),
]

# 两格 SVG atlas 是本场景唯一贴图源；普通 atlas tile 才能被导出脚本接受。
const TILE_TEXTURE: Texture2D = preload("res://Tools/MapAuthoring/NavigationTiles.svg")

# 这些字段会由导出脚本写入公共 JSON，修改地图语义时应同时递增 map_version。
@export var map_id: String = "navigation_test_map"
@export var map_version: int = 1

# 检查器按钮用于主动清空当前手绘内容，并恢复下面公式定义的基准地图。
@export_tool_button("重建基准地图") var rebuild_map_button: Callable = rebuild_map


func _ready() -> void:
	# 空场景首次进入编辑器时没有 TileSet，先创建带 terrain_id 的制图资源。
	if tile_set == null:
		_create_tileset()

	# TileMapLayer 会在 _ready() 之后批量完成内部更新；延迟到下一轮再写 TileData，
	# 可以保证自定义数据不会被这次初始化恢复成类型默认值。
	if get_used_cells().is_empty():
		call_deferred("_finish_initial_map_build")
	else:
		_apply_tileset_custom_data()


func get_block_size() -> int:
	# 常量不会作为普通 Node 属性暴露；导出脚本通过这个只读方法取得 v1 block 尺寸。
	return BLOCK_SIZE


func rebuild_map() -> void:
	# 按钮也可能在 TileSet 被手动移除后触发，因此这里再次保证资源存在。
	if tile_set == null:
		_create_tileset()
	_apply_tileset_custom_data()

	# 先删除旧格子，使重建结果只由本脚本中的 block 公式决定。
	clear()

	# 先遍历 block，再展开其内部 2×2 tile；这样天然保证一个 block 内地形一致。
	for block_y in range(MAP_BLOCK_MIN.y, MAP_BLOCK_MAX_EXCLUSIVE.y):
		for block_x in range(MAP_BLOCK_MIN.x, MAP_BLOCK_MAX_EXCLUSIVE.x):
			var block_coord := Vector2i(block_x, block_y)
			var terrain_id := _terrain_id_for_block(block_coord)
			var atlas_coord := _atlas_coord_for_terrain(terrain_id)

			# block 左上角 tile 坐标 = block 坐标 × BLOCK_SIZE，这就是 v1 的反向换算。
			var first_tile := block_coord * BLOCK_SIZE
			for local_y in range(BLOCK_SIZE):
				for local_x in range(BLOCK_SIZE):
					var cell := first_tile + Vector2i(local_x, local_y)
					set_cell(cell, SOURCE_ID, atlas_coord, 0)

	# 通知编辑器资源发生改变，使场景标签显示未保存状态，提醒用户保存制图源。
	update_internals()
	queue_redraw()
	if Engine.is_editor_hint():
		EditorInterface.mark_scene_as_unsaved()


func _finish_initial_map_build() -> void:
	# deferred 调用时 TileMapLayer 已完成入树初始化，现在写自定义值并铺设基准地图。
	_apply_tileset_custom_data()
	rebuild_map()


func _create_tileset() -> void:
	# TileSet 是格子尺寸、atlas source 和自定义数据层的共同容器。
	var new_tile_set := TileSet.new()
	new_tile_set.resource_name = "NavigationTestMapTileSet"
	new_tile_set.tile_size = TILE_SIZE

	# 自定义数据层名固定为 terrain_id；导出脚本只认这个机器契约。
	new_tile_set.add_custom_data_layer()
	new_tile_set.set_custom_data_layer_name(0, "terrain_id")
	new_tile_set.set_custom_data_layer_type(0, TYPE_INT)

	# atlas source 把 32×16 SVG 按 16×16 切成横向两个普通 tile。
	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = TILE_TEXTURE
	atlas_source.texture_region_size = TILE_SIZE
	atlas_source.create_tile(GRASS_ATLAS_COORD)
	atlas_source.create_tile(WATER_ATLAS_COORD)

	# 先把 atlas source 加入 TileSet，TileData 才能关联上面声明的自定义数据层。
	# source_id 固定为 0，之后 set_cell 和导出校验都使用同一个 ID。
	new_tile_set.add_source(atlas_source, SOURCE_ID)
	# 把完整 TileSet 交给 TileMapLayer；自定义值会在节点完成初始化后单独写入。
	tile_set = new_tile_set


func _apply_tileset_custom_data() -> void:
	# 从当前 TileSet 取得 active source，确保修改的是 TileMapLayer 正在使用的资源。
	var active_atlas_source := tile_set.get_source(SOURCE_ID) as TileSetAtlasSource
	if active_atlas_source == null:
		push_error("[NavigationTestMap] TileSet 缺少 source_id=0 的 atlas source。")
		return

	# terrain_id 写在 TileData 上；同一种 tile 的所有放置实例共享同一个逻辑值。
	var grass_tile_data := active_atlas_source.get_tile_data(GRASS_ATLAS_COORD, 0)
	grass_tile_data.set_custom_data_by_layer_id(0, TERRAIN_GRASS)
	var water_tile_data := active_atlas_source.get_tile_data(WATER_ATLAS_COORD, 0)
	water_tile_data.set_custom_data_by_layer_id(0, TERRAIN_WATER)


func _terrain_id_for_block(block_coord: Vector2i) -> int:
	# 只要落在内部范围之外但仍在总地图范围内，就是四周 2 block 的水边界。
	if block_coord.x < WALKABLE_BLOCK_MIN.x or block_coord.x >= WALKABLE_BLOCK_MAX_EXCLUSIVE.x:
		return TERRAIN_WATER
	if block_coord.y < WALKABLE_BLOCK_MIN.y or block_coord.y >= WALKABLE_BLOCK_MAX_EXCLUSIVE.y:
		return TERRAIN_WATER

	# 内部矩形命中任一池塘时也是水；池塘之外的可移动区域全部为草地。
	for pond_rect: Rect2i in POND_BLOCK_RECTS:
		if pond_rect.has_point(block_coord):
			return TERRAIN_WATER
	return TERRAIN_GRASS


func _atlas_coord_for_terrain(terrain_id: int) -> Vector2i:
	# 逻辑地形到贴图只在客户端制图源映射，JSON 和服务端都不保存 atlas 坐标。
	if terrain_id == TERRAIN_WATER:
		return WATER_ATLAS_COORD
	return GRASS_ATLAS_COORD
