@tool
extends EditorScript

## 文件：client/Tools/MapAuthoring/ExportNavigationTestMap.gd
## 作用：把当前打开的 NavigationTestMap.tscn 中 Terrain 层导出为双端公共 JSON。
##
## 在 Godot 脚本编辑器打开本文件并执行“运行”即可调用 _run()。
## 脚本只读取 TileMapLayer；任何空格、非 atlas tile、缺失 terrain_id、非 2×2
## block 对齐或旋转缩放都会直接报错，避免障碍被静默漏掉。

# 导出文件位于 Godot 项目目录 client 的上一级公共配置目录中。
const OUTPUT_PATH: String = "res://../json_config/navigation_test_map.json"

# 场景中逻辑地形层固定使用这个节点名；装饰层以后可另建，但不会被本脚本读取。
const TERRAIN_LAYER_PATH: NodePath = NodePath("Terrain")

# TileSet 自定义数据层保存逻辑地形 ID，通行性仍由 terrain_config.json 唯一决定。
const TERRAIN_CUSTOM_DATA: StringName = &"terrain_id"

# JSON 结构版本与地图内容版本分离；字段结构改变才递增 SCHEMA_VERSION。
const SCHEMA_VERSION: int = 2

func _run() -> void:
	# EditorScript 应导出当前正在编辑的场景，这样用户未保存的可见改动也不会被忽略。
	var scene_root := get_editor_interface().get_edited_scene_root()
	export_scene_root(scene_root)


static func export_scene_root(scene_root: Node) -> void:
	# 静态核心既供 _run() 调用，也允许无界面验收对同一导出实现做真实测试。
	if scene_root == null:
		_fail("没有正在编辑的场景；请先打开 NavigationTestMap.tscn。")
		return

	# 只接受约定的 Terrain 节点，防止误把装饰层或其他场景导出成逻辑地图。
	var terrain_node := scene_root.get_node_or_null(TERRAIN_LAYER_PATH)
	if terrain_node == null or not terrain_node is TileMapLayer:
		_fail("当前场景缺少 TileMapLayer 节点 Terrain。")
		return
	var terrain_layer := terrain_node as TileMapLayer

	# 首版坐标公式假定逻辑层与场景根同原点且无变换，否则双端世界坐标会产生歧义。
	if not _validate_identity_transform(scene_root, terrain_layer):
		return

	# 没有 TileSet 就无法知道 tile 尺寸，也无法读取 TileData.terrain_id。
	if terrain_layer.tile_set == null:
		_fail("Terrain 层没有 TileSet。")
		return
	var tile_size := terrain_layer.tile_set.tile_size
	if tile_size.x <= 0 or tile_size.y <= 0:
		_fail("TileSet.tile_size 必须为正数。")
		return

	# block_size 从制图脚本读取，确保 JSON 使用的仍是 v1 的 2×2 公式。
	if not terrain_layer.has_method("get_block_size"):
		_fail("Terrain 脚本缺少 get_block_size()，无法确认 v1 block 公式。")
		return
	var block_size := int(terrain_layer.call("get_block_size"))
	if block_size != 2:
		_fail("首版导出只接受 BLOCK_SIZE=2，当前值=%d。" % block_size)
		return

	# used_rect 是最小外接矩形；后面会验证矩形内无空格，范围外默认不可走。
	var used_rect := terrain_layer.get_used_rect()
	var used_cells := terrain_layer.get_used_cells()
	if used_cells.is_empty() or used_rect.size.x <= 0 or used_rect.size.y <= 0:
		_fail("Terrain 层为空，不能导出。")
		return

	# 完整矩形应有 width×height 个 tile；数量不足说明中间有未声明格子，必须显式修正。
	var expected_cell_count := used_rect.size.x * used_rect.size.y
	if used_cells.size() != expected_cell_count:
		_fail("Terrain 范围内存在空格：期望 %d 格，实际 %d 格。" % [expected_cell_count, used_cells.size()])
		return

	# 地图起点和长宽都必须是 block_size 的整数倍，否则边缘会出现半个 block。
	if used_rect.position.x % block_size != 0 or used_rect.position.y % block_size != 0:
		_fail("Terrain 最小 cell 坐标没有按 2×2 block 对齐：%s。" % used_rect.position)
		return
	if used_rect.size.x % block_size != 0 or used_rect.size.y % block_size != 0:
		_fail("Terrain 尺寸没有按 2×2 block 对齐：%s。" % used_rect.size)
		return

	# 固定为先 y 后 x，使逐格校验过程和错误出现顺序保持稳定。
	used_cells.sort_custom(_sort_cells_by_row)
	var block_terrain_ids: Dictionary = {}

	for cell: Vector2i in used_cells:
		# source_id<0 表示空格；这里再次逐格防御，避免未来 API 行为变化造成静默遗漏。
		var source_id := terrain_layer.get_cell_source_id(cell)
		if source_id < 0:
			_fail("cell %s 没有有效 source_id。" % cell)
			return

		# atlas 坐标为 (-1,-1) 通常表示 scene tile 等非普通 atlas tile，首版明确不支持。
		var atlas_coord := terrain_layer.get_cell_atlas_coords(cell)
		if atlas_coord == Vector2i(-1, -1):
			_fail("cell %s 不是普通 atlas tile。" % cell)
			return

		# alternative_tile=0 才是原始 atlas tile；旋转、翻转和替代 tile 首版全部拒绝。
		var alternative_tile := terrain_layer.get_cell_alternative_tile(cell)
		if alternative_tile != 0:
			_fail("cell %s 使用了 alternative tile=%d，首版不支持。" % [cell, alternative_tile])
			return

		# TileData 来自 TileSet 中该 atlas tile 的定义，因此同一种 tile 的实例共享 terrain_id。
		var tile_data := terrain_layer.get_cell_tile_data(cell)
		if tile_data == null:
			_fail("cell %s 无法取得 TileData。" % cell)
			return
		if not tile_data.has_custom_data(TERRAIN_CUSTOM_DATA):
			_fail("cell %s 的 TileData 缺少 terrain_id 自定义数据。" % cell)
			return
		var terrain_value: Variant = tile_data.get_custom_data(TERRAIN_CUSTOM_DATA)
		if typeof(terrain_value) != TYPE_INT:
			_fail("cell %s 的 terrain_id 不是 int。" % cell)
			return
		var terrain_id := int(terrain_value)
		if terrain_id < 0 or terrain_id > 255:
			_fail("cell %s 的 terrain_id=%d 超出 uint8 范围 0..255。" % [cell, terrain_id])
			return

		# v1 block 坐标公式与旧版一致：block=floor(cell/BLOCK_SIZE)，负坐标也向负无穷取整。
		var block_coord := Vector2i(
			floori(float(cell.x) / float(block_size)),
			floori(float(cell.y) / float(block_size))
		)
		if block_terrain_ids.has(block_coord) and int(block_terrain_ids[block_coord]) != terrain_id:
			_fail("block %s 内出现多个 terrain_id，不满足 v1 同 block 同地形公式。" % block_coord)
			return
		block_terrain_ids[block_coord] = terrain_id

	# cell 范围已经按 block 对齐，所以整除即可得到有限 block 范围。
	var block_min := Vector2i(
		floori(float(used_rect.position.x) / float(block_size)),
		floori(float(used_rect.position.y) / float(block_size))
	)
	var block_count := Vector2i(
		floori(float(used_rect.size.x) / float(block_size)),
		floori(float(used_rect.size.y) / float(block_size))
	)
	var block_max_exclusive := block_min + block_count
	var expected_block_count := block_count.x * block_count.y
	if block_terrain_ids.size() != expected_block_count:
		_fail("block 数量不完整：期望 %d，实际 %d。" % [expected_block_count, block_terrain_ids.size()])
		return

	# terrain_ids 只保存地形值，不重复保存每个坐标；索引按先 y 后 x 的 row-major 公式计算。
	var exported_terrain_ids: Array = []
	for block_y in range(block_min.y, block_max_exclusive.y):
		for block_x in range(block_min.x, block_max_exclusive.x):
			var block_coord := Vector2i(block_x, block_y)
			if not block_terrain_ids.has(block_coord):
				_fail("block %s 没有对应 terrain_id。" % block_coord)
				return
			exported_terrain_ids.append(int(block_terrain_ids[block_coord]))

	# map_to_local() 返回格心；identity transform 下再 to_global() 就是双端对照用的世界格心。
	var origin_cell := Vector2i.ZERO
	var origin_center_world := terrain_layer.to_global(terrain_layer.map_to_local(origin_cell))
	var bounds_max_exclusive := used_rect.position + used_rect.size

	# JSON 只记录逻辑事实；atlas 坐标和 blocked 均不导出，避免与 terrain_config 重复维护。
	var document := {
		"schema_version": SCHEMA_VERSION,
		"map_id": str(terrain_layer.get("map_id")),
		"map_version": int(terrain_layer.get("map_version")),
		"tile_size_px": [tile_size.x, tile_size.y],
		"block_size": [block_size, block_size],
		"cell_bounds": {
			"min_inclusive": [used_rect.position.x, used_rect.position.y],
			"max_exclusive": [bounds_max_exclusive.x, bounds_max_exclusive.y],
		},
		"block_bounds": {
			"min_inclusive": [block_min.x, block_min.y],
			"max_exclusive": [block_max_exclusive.x, block_max_exclusive.y],
			"size": [block_count.x, block_count.y],
		},
		"coordinate_system": {
			"cell_axis_x": "right",
			"cell_axis_y": "down",
			"origin_cell": [origin_cell.x, origin_cell.y],
			"origin_cell_center_world_px": [origin_center_world.x, origin_center_world.y],
			"cell_center_formula": "world=(cell+0.5)*tile_size_px",
			"block_to_first_cell_formula": "first_cell=block*block_size",
			"outside_bounds_walkable": false,
			"undeclared_block_walkable": false,
		},
		"terrain_encoding": {
			"layout": "row_major",
			"value_type": "uint8",
			"index_formula": "index=(block_y-min_y)*width+(block_x-min_x)",
		},
		"terrain_ids": exported_terrain_ids,
	}

	# sort_keys=true 配合固定 row-major 顺序，使相同制图源每次导出得到相同文本。
	var json_text := JSON.stringify(document, "\t", true, true) + "\n"
	var absolute_output_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	var output_file := FileAccess.open(absolute_output_path, FileAccess.WRITE)
	if output_file == null:
		_fail("无法写入 %s：%s。" % [absolute_output_path, error_string(FileAccess.get_open_error())])
		return
	output_file.store_string(json_text)
	output_file.close()

	# 控制台给出可核对的范围和数量；之后运行 tools/sync_config.py 即可复制给双端。
	print("[MapExporter] 导出成功：", absolute_output_path)
	print("[MapExporter] map_id=", document["map_id"], " version=", document["map_version"])
	print("[MapExporter] cell_bounds=", used_rect, " blocks=", exported_terrain_ids.size())


static func _validate_identity_transform(scene_root: Node, terrain_layer: TileMapLayer) -> bool:
	# 根节点不是 Node2D 时无法建立当前 2D 世界坐标契约。
	if not scene_root is Node2D:
		_fail("地图场景根节点必须是 Node2D。")
		return false
	var root_2d := scene_root as Node2D

	# 分别检查根和 Terrain，错误信息能直接指出应在检查器里复原哪个节点。
	if not root_2d.position.is_equal_approx(Vector2.ZERO):
		_fail("地图根节点 position 必须为 (0,0)。")
		return false
	if not is_zero_approx(root_2d.rotation) or not is_zero_approx(root_2d.skew):
		_fail("地图根节点 rotation 和 skew 必须为 0。")
		return false
	if not root_2d.scale.is_equal_approx(Vector2.ONE):
		_fail("地图根节点 scale 必须为 (1,1)。")
		return false
	if not terrain_layer.position.is_equal_approx(Vector2.ZERO):
		_fail("Terrain.position 必须为 (0,0)。")
		return false
	if not is_zero_approx(terrain_layer.rotation) or not is_zero_approx(terrain_layer.skew):
		_fail("Terrain.rotation 和 Terrain.skew 必须为 0。")
		return false
	if not terrain_layer.scale.is_equal_approx(Vector2.ONE):
		_fail("Terrain.scale 必须为 (1,1)。")
		return false
	return true


static func _sort_cells_by_row(left: Vector2i, right: Vector2i) -> bool:
	# 先比较 y 形成逐行顺序，同一行再比较 x 形成从左到右顺序。
	if left.y == right.y:
		return left.x < right.x
	return left.y < right.y


static func _fail(message: String) -> void:
	# 所有校验失败统一加前缀，便于在 Godot 输出面板中过滤地图导出问题。
	push_error("[MapExporter] " + message)
