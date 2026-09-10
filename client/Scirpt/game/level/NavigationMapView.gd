extends TileMapLayer
class_name NavigationMapView

const BLOCK_SIZE: int = 2
const TILE_SIZE := Vector2i(16, 16)
const TILE_SET_FILE_PATH := ["res://Prefab/TiledMap/TileSet.png", "res://Prefab/TiledMap/NavigationTiles.svg"]


var map: ConfigLoader.NavigationMap = null
func _ready() -> void:
	tile_set = TileSet.new()
	load_to_json()
	tile_set.tile_size = map.tile_size_px
	tile_set.tile_shape = TileSet.TileShape.TILE_SHAPE_SQUARE

	for file_path in TILE_SET_FILE_PATH:
		var atlas_source := TileSetAtlasSource.new()
		var texture := ResourceLoader.load(file_path)
		if not texture:
			continue

		atlas_source.texture = texture
		atlas_source.texture_region_size = map.tile_size_px
		var grid_size = atlas_source.get_atlas_grid_size()
		# 根据texture的大小来创建tile
		for x in range(grid_size[0]):
			for y in range(grid_size[1]):
				atlas_source.create_tile(Vector2i(x, y))
		tile_set.add_source(atlas_source)

func _process(_delta: float) -> void:
	pass

func load_to_json() -> void:
	# 根据json数据来还原整个地图
	map = ConfigLoader.get_navigation_map("navigation_test_map")
	if not map:
		return

	for x in range(map.block_bounds_start[0], map.block_bounds_end[0]):
		for y in range(map.block_bounds_start[1], map.block_bounds_end[1]):
			set_block(Vector2i(x, y))

func set_block(pos: Vector2i):
	var block_x = pos[0]
	var block_y = pos[1]

	# block左上角的瓦片坐标 0是在正方向的 负方向第一个就是-1
	var tile_start_x = block_x * map.block_size[0]
	var tile_start_y = block_y * map.block_size[1]
	var tile_end_x = tile_start_x + map.block_size[0] - 1
	var tile_end_y = tile_start_y + map.block_size[1] - 1
	
	# 先用第二个纹理 之后再改成第一个纹理的
	var source_id := 1
	# block中4个cell的纹理都是同一个
	var atlas_coords := get_cell_texture(block_x, block_y)
	for x in range(tile_start_x, tile_end_x + 1):
		for y in range(tile_start_y, tile_end_y + 1):
			set_cell(Vector2i(x, y), source_id, atlas_coords)


# 获取瓦片的纹理位置和
func get_cell_texture(tile_x: int, tile_y: int) -> Vector2i:
	# 这个是用来旋转的 先不还原
	# var variant_alt: int = _get_or_create_alt_tile(variant_tc.assets_pos, variant_tc.dir)


	#terrain_idx 是从0开始的  tile_x, tile_y有可能是负的  最左上角的tile_x, tile_y对应的terrain_idx是0
	var map_x_size = map.block_bounds_end[0] - map.block_bounds_start[0]
	var map_y_size = map.block_bounds_end[1] - map.block_bounds_start[1]
	var terrain_idx = (tile_y + map_y_size / 2) * map_x_size + (tile_x + map_x_size / 2)
	# print("tile_x ", tile_x, " tile_y ", tile_y, " idx ", terrain_idx)
	var tile_type = map.terrain_ids[terrain_idx]
	if tile_type == 0:
		return Vector2i(0, 0)
	else:
		return Vector2i(1, 0)
	
	
