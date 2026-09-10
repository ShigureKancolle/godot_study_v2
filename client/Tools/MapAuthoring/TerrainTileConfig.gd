extends RefCounted
class_name TerrainTileConfig

## 文件：client/Tools/MapAuthoring/TerrainTileConfig.gd
## 作用：集中保存 Tileset.png 中沙地、泥地、砖地和水的 atlas 格子配置。
##
## 本文件只描述渲染素材，不保存地图逻辑，也不直接修改 TileMapLayer。
## 沙地、泥地和砖地共用 blob 过渡规则：一个逻辑 block 由 2×2 个 tile 组成，
## mask 的 bit 表示对应邻居是否为异类地形。水岸有上下层次，使用独立形态表。

const TILE_SIZE := Vector2i(16, 16)
const ATLAS_GRID_SIZE := Vector2i(18, 27)
const TILESET_PATH: String = "res://Prefab/TiledMap/Tileset.png"

# terrain_id 与 terrain_config.json 以及既有 TerrainType 顺序保持一致。
const TERRAIN_SAND: int = 1
const TERRAIN_DIRT: int = 2
const TERRAIN_BRICK: int = 3
const TERRAIN_WATER: int = 4

# 2×2 block 内的索引顺序固定为：左上、右上、左下、右下。
const CELL_TOP_LEFT: int = 0
const CELL_TOP_RIGHT: int = 1
const CELL_BOTTOM_LEFT: int = 2
const CELL_BOTTOM_RIGHT: int = 3

# mask 从正上方开始顺时针排列；bit=1 表示该方向是异类地形。
const MASK_TOP: int = 1 << 0
const MASK_TOP_RIGHT: int = 1 << 1
const MASK_RIGHT: int = 1 << 2
const MASK_BOTTOM_RIGHT: int = 1 << 3
const MASK_BOTTOM: int = 1 << 4
const MASK_BOTTOM_LEFT: int = 1 << 5
const MASK_LEFT: int = 1 << 6
const MASK_TOP_LEFT: int = 1 << 7

# 去除被直边覆盖的对角后，全部 256 个 mask 旋转归一得到这 15 种形态。
const LAND_CANONICAL_MASKS: Array[int] = [
	0, 1, 2, 5, 9, 10, 17, 18, 21, 34, 37, 41, 42, 85, 170,
]

enum BlobPart {
	PURE,
	TOP,
	OUTER_CORNER,
	INNER_CORNER,
}


## 返回四种地形的完整配置。返回值是新建字典，调用方可以安全地补充运行时数据。
static func get_all_terrain_configs() -> Dictionary:
	return {
		TERRAIN_SAND: _build_land_config(
			TERRAIN_SAND, &"SAND", 4, 10, 6, 5
		),
		TERRAIN_DIRT: _build_land_config(
			TERRAIN_DIRT, &"DIRT", 0, 6, 1, 2
		),
		TERRAIN_BRICK: _build_land_config(
			TERRAIN_BRICK, &"BRICK", 8, 8, 9, 10
		),
		TERRAIN_WATER: _build_water_config(),
	}


## 按 terrain_id 返回单种地形配置；未知 ID 返回空字典。
static func get_terrain_config(terrain_id: int) -> Dictionary:
	var all_configs := get_all_terrain_configs()
	var config_value: Variant = all_configs.get(terrain_id)
	if config_value == null or not config_value is Dictionary:
		return {}
	return config_value as Dictionary


## 解析沙地、泥地或砖地的任意 8-bit mask。
##
## 返回字段：
## - input_mask：调用方传入并截断到 8 bit 的 mask。
## - covered_mask：去掉已被相邻直边覆盖的对角 bit。
## - canonical_mask：四个旋转方向中数值最小的规范 mask。
## - rotations_to_canonical：原方向顺时针旋转多少次得到规范方向。
## - rotations_to_original：规范形态顺时针旋转多少次恢复原方向。
## - cells：已经恢复到原方向的四格部件配置。
static func resolve_land_form(mask: int) -> Dictionary:
	var input_mask: int = mask & 0xFF
	var covered_mask := reduce_covered_corners(input_mask)
	var normalized := normalize_mask_rotation(covered_mask)
	var canonical_mask: int = normalized["mask"]
	var rotations_to_canonical: int = normalized["rotations"]
	var rotations_to_original: int = (4 - rotations_to_canonical) % 4
	var canonical_cells := _build_land_form_cells(canonical_mask)
	var output_cells := _rotate_land_cells(canonical_cells, rotations_to_original)
	return {
		"input_mask": input_mask,
		"covered_mask": covered_mask,
		"canonical_mask": canonical_mask,
		"rotations_to_canonical": rotations_to_canonical,
		"rotations_to_original": rotations_to_original,
		"cells": output_cells,
	}


## 去掉已被直边过渡覆盖的对角 bit。
## 只有一个对角的两条相邻直边都还是本地形时，才需要保留内凹角。
static func reduce_covered_corners(mask: int) -> int:
	var input_mask: int = mask & 0xFF
	var result: int = input_mask & (MASK_TOP | MASK_RIGHT | MASK_BOTTOM | MASK_LEFT)

	if input_mask & MASK_TOP_RIGHT and not input_mask & MASK_TOP and not input_mask & MASK_RIGHT:
		result |= MASK_TOP_RIGHT
	if input_mask & MASK_BOTTOM_RIGHT and not input_mask & MASK_RIGHT and not input_mask & MASK_BOTTOM:
		result |= MASK_BOTTOM_RIGHT
	if input_mask & MASK_BOTTOM_LEFT and not input_mask & MASK_BOTTOM and not input_mask & MASK_LEFT:
		result |= MASK_BOTTOM_LEFT
	if input_mask & MASK_TOP_LEFT and not input_mask & MASK_LEFT and not input_mask & MASK_TOP:
		result |= MASK_TOP_LEFT
	return result


## 顺时针旋转一个 mask 90 度。
static func rotate_mask_clockwise(mask: int) -> int:
	var input_mask: int = mask & 0xFF
	var result: int = 0
	if input_mask & MASK_TOP:
		result |= MASK_RIGHT
	if input_mask & MASK_TOP_RIGHT:
		result |= MASK_BOTTOM_RIGHT
	if input_mask & MASK_RIGHT:
		result |= MASK_BOTTOM
	if input_mask & MASK_BOTTOM_RIGHT:
		result |= MASK_BOTTOM_LEFT
	if input_mask & MASK_BOTTOM:
		result |= MASK_LEFT
	if input_mask & MASK_BOTTOM_LEFT:
		result |= MASK_TOP_LEFT
	if input_mask & MASK_LEFT:
		result |= MASK_TOP
	if input_mask & MASK_TOP_LEFT:
		result |= MASK_TOP_RIGHT
	return result


## 在原方向及其三个顺时针旋转中选数值最小的 mask。
static func normalize_mask_rotation(mask: int) -> Dictionary:
	var minimum_mask: int = mask & 0xFF
	var minimum_rotations: int = 0
	var current_mask: int = minimum_mask
	for rotation in range(1, 4):
		current_mask = rotate_mask_clockwise(current_mask)
		if current_mask < minimum_mask:
			minimum_mask = current_mask
			minimum_rotations = rotation
	return {
		"mask": minimum_mask,
		"rotations": minimum_rotations,
	}


## 检查 atlas 坐标、权重、方向和形态引用，返回全部错误；空数组表示通过。
static func validate_all_configs() -> PackedStringArray:
	var errors := PackedStringArray()
	var all_configs := get_all_terrain_configs()

	for terrain_id: int in [TERRAIN_SAND, TERRAIN_DIRT, TERRAIN_BRICK]:
		var land_config: Dictionary = all_configs[terrain_id]
		var parts: Dictionary = land_config["parts"]
		for part_value: Variant in parts.keys():
			_validate_candidates(
				parts[part_value],
				"%s.parts[%s]" % [land_config["name"], part_value],
				errors
			)

	var water_config: Dictionary = all_configs[TERRAIN_WATER]
	var water_roles: Dictionary = water_config["roles"]
	for role_value: Variant in water_roles.keys():
		_validate_candidates(
			water_roles[role_value],
			"WATER.roles[%s]" % role_value,
			errors
		)

	var water_forms: Dictionary = water_config["forms"]
	for form_value: Variant in water_forms.keys():
		var form_cells: Array = water_forms[form_value]
		if form_cells.size() != 4:
			errors.append("WATER.forms[%s] 必须包含四个 cell。" % form_value)
			continue
		for cell_index in range(form_cells.size()):
			var form_cell: Dictionary = form_cells[cell_index]
			var role: StringName = form_cell["role"]
			if not water_roles.has(role):
				errors.append(
					"WATER.forms[%s][%d] 引用了未知 role=%s。" % [form_value, cell_index, role]
				)

	for input_mask in range(256):
		var resolved := resolve_land_form(input_mask)
		var canonical_mask: int = resolved["canonical_mask"]
		if canonical_mask not in LAND_CANONICAL_MASKS:
			errors.append("mask=%d 得到了未登记的规范 mask=%d。" % [input_mask, canonical_mask])
		var resolved_cells: Array = resolved["cells"]
		if resolved_cells.size() != 4:
			errors.append("mask=%d 没有解析成四个 cell。" % input_mask)

	return errors


## 构造沙地、泥地或砖地的候选池。
## blob_start_x 指向 4×3 外轮廓组左上角；inner_start_x 指向 2×2 内凹角组左上角。
static func _build_land_config(
	terrain_id: int,
	terrain_name: StringName,
	blob_start_x: int,
	inner_start_x: int,
	pure_main_x: int,
	pure_rare_x: int
) -> Dictionary:
	var pure_candidates: Array = []
	_append_four_rotations(pure_candidates, Vector2i(pure_main_x, 10), 100)
	_append_four_rotations(pure_candidates, Vector2i(pure_rare_x, 10), 1)

	var top_candidates: Array = [
		_candidate(Vector2i(blob_start_x + 1, 9), 0, 100 if pure_main_x == blob_start_x + 1 else 1),
		_candidate(Vector2i(blob_start_x + 2, 9), 0, 100 if pure_main_x == blob_start_x + 2 else 1),
		_candidate(Vector2i(blob_start_x + 1, 11), 2, 1),
		_candidate(Vector2i(blob_start_x + 2, 11), 2, 1),
		_candidate(Vector2i(blob_start_x, 10), 1, 1),
		_candidate(Vector2i(blob_start_x + 3, 10), 3, 1),
	]

	var outer_corner_candidates: Array = [
		_candidate(Vector2i(blob_start_x + 3, 9), 0, 1),
		_candidate(Vector2i(blob_start_x, 9), 1, 1),
		_candidate(Vector2i(blob_start_x, 11), 2, 1),
		_candidate(Vector2i(blob_start_x + 3, 11), 3, 1),
	]

	var inner_corner_candidates: Array = [
		_candidate(Vector2i(inner_start_x, 7), 0, 1),
		_candidate(Vector2i(inner_start_x + 1, 7), 1, 1),
		_candidate(Vector2i(inner_start_x + 1, 6), 2, 1),
		_candidate(Vector2i(inner_start_x, 6), 3, 1),
	]

	return {
		"terrain_id": terrain_id,
		"name": terrain_name,
		"kind": &"LAND_BLOB",
		"canonical_masks": LAND_CANONICAL_MASKS,
		"parts": {
			BlobPart.PURE: pure_candidates,
			BlobPart.TOP: top_candidates,
			BlobPart.OUTER_CORNER: outer_corner_candidates,
			BlobPart.INNER_CORNER: inner_corner_candidates,
		},
	}


## 根据规范 mask 为四个象限选择纯地块、直边、外凸角或内凹角。
static func _build_land_form_cells(mask: int) -> Array:
	return [
		_resolve_land_quadrant(
			mask, MASK_TOP, 0, MASK_LEFT, 3, MASK_TOP_LEFT, 3, 3
		),
		_resolve_land_quadrant(
			mask, MASK_TOP, 0, MASK_RIGHT, 1, MASK_TOP_RIGHT, 0, 0
		),
		_resolve_land_quadrant(
			mask, MASK_BOTTOM, 2, MASK_LEFT, 3, MASK_BOTTOM_LEFT, 2, 2
		),
		_resolve_land_quadrant(
			mask, MASK_BOTTOM, 2, MASK_RIGHT, 1, MASK_BOTTOM_RIGHT, 1, 1
		),
	]


static func _resolve_land_quadrant(
	mask: int,
	first_edge: int,
	first_edge_rotation: int,
	second_edge: int,
	second_edge_rotation: int,
	diagonal: int,
	inner_corner_rotation: int,
	outer_corner_rotation: int
) -> Dictionary:
	var has_first_edge: bool = bool(mask & first_edge)
	var has_second_edge: bool = bool(mask & second_edge)
	if has_first_edge and has_second_edge:
		return _land_cell(BlobPart.OUTER_CORNER, outer_corner_rotation)
	if has_first_edge:
		return _land_cell(BlobPart.TOP, first_edge_rotation)
	if has_second_edge:
		return _land_cell(BlobPart.TOP, second_edge_rotation)
	if mask & diagonal:
		return _land_cell(BlobPart.INNER_CORNER, inner_corner_rotation)
	return _land_cell(BlobPart.PURE, 0)


static func _rotate_land_cells(source_cells: Array, times: int) -> Array:
	var result: Array = source_cells.duplicate(true)
	for _rotation in range(times % 4):
		result = [
			_rotate_land_cell(result[CELL_BOTTOM_LEFT]),
			_rotate_land_cell(result[CELL_TOP_LEFT]),
			_rotate_land_cell(result[CELL_BOTTOM_RIGHT]),
			_rotate_land_cell(result[CELL_TOP_RIGHT]),
		]
	return result


static func _rotate_land_cell(source_cell: Dictionary) -> Dictionary:
	return _land_cell(
		int(source_cell["part"]),
		(int(source_cell["rotation"]) + 1) % 4
	)


static func _land_cell(part: int, rotation: int) -> Dictionary:
	return {
		"part": part,
		"rotation": rotation % 4,
	}


## 水岸素材不能只靠四种 blob 部件旋转，保留 v1 验证过的独立角色和 form。
static func _build_water_config() -> Dictionary:
	var roles := {
		&"PURE": [
			_candidate(Vector2i(10, 14), 0, 100),
			_candidate(Vector2i(10, 20), 0, 1),
			_candidate(Vector2i(11, 20), 0, 1),
		],
		&"SHORE_TOP": [_candidate(Vector2i(10, 12), 0, 1)],
		&"WATER_TOP": [_candidate(Vector2i(10, 13), 0, 1)],
		&"SHORE_TOP_RIGHT": [_candidate(Vector2i(11, 12), 0, 1)],
		&"WATER_TOP_RIGHT": [_candidate(Vector2i(11, 13), 0, 1)],
		&"WATER_BOTTOM_RIGHT": [_candidate(Vector2i(11, 15), 0, 1)],
		&"SHORE_TOP_LEFT": [_candidate(Vector2i(9, 12), 0, 1)],
		&"WATER_TOP_LEFT": [_candidate(Vector2i(9, 13), 0, 1)],
		&"SHORE_INNER_RIGHT": [_candidate(Vector2i(9, 18), 0, 1)],
		&"WATER_INNER_RIGHT": [_candidate(Vector2i(9, 19), 0, 1)],
		&"WATER_INNER_BOTTOM": [_candidate(Vector2i(9, 16), 0, 1)],
		&"SHORE_INNER_LEFT": [_candidate(Vector2i(11, 18), 0, 1)],
		&"WATER_INNER_LEFT": [_candidate(Vector2i(11, 19), 0, 1)],
		&"SHORE_SIDE": [_candidate(Vector2i(11, 14), 0, 1)],
		&"SHORE_BOTTOM_CORNER": [_candidate(Vector2i(11, 15), 0, 1)],
	}

	var forms := {
		0: _water_cells(&"PURE", &"PURE", &"PURE", &"PURE"),
		1: _water_cells(&"SHORE_TOP", &"SHORE_TOP", &"WATER_TOP", &"WATER_TOP"),
		2: _water_cells(&"PURE", &"SHORE_INNER_RIGHT", &"PURE", &"WATER_INNER_RIGHT"),
		4: _water_cells(&"PURE", &"SHORE_SIDE", &"PURE", &"SHORE_SIDE"),
		5: _water_cells(&"SHORE_TOP", &"SHORE_TOP_RIGHT", &"WATER_TOP", &"WATER_TOP_RIGHT"),
		8: _water_cells(&"PURE", &"PURE", &"PURE", &"WATER_INNER_BOTTOM"),
		9: _water_cells(&"SHORE_TOP", &"SHORE_TOP", &"WATER_TOP", &"WATER_INNER_BOTTOM"),
		18: _water_cells_rotated(
			[&"PURE", &"SHORE_INNER_RIGHT", &"SHORE_SIDE", &"SHORE_SIDE"],
			[0, 0, 1, 1]
		),
		20: _water_cells_rotated(
			[&"PURE", &"SHORE_SIDE", &"SHORE_SIDE", &"SHORE_BOTTOM_CORNER"],
			[0, 0, 1, 0]
		),
		33: _water_cells_rotated(
			[&"SHORE_TOP", &"SHORE_TOP", &"WATER_INNER_BOTTOM", &"PURE"],
			[0, 0, 1, 0]
		),
		34: _water_cells_rotated(
			[&"PURE", &"SHORE_INNER_RIGHT", &"WATER_INNER_BOTTOM", &"WATER_INNER_RIGHT"],
			[0, 0, 1, 0]
		),
		36: _water_cells_rotated(
			[&"PURE", &"SHORE_SIDE", &"WATER_INNER_BOTTOM", &"SHORE_SIDE"],
			[0, 1, 1, 1]
		),
		37: _water_cells_rotated(
			[&"SHORE_TOP", &"SHORE_TOP_RIGHT", &"WATER_INNER_BOTTOM", &"SHORE_SIDE"],
			[0, 0, 1, 0]
		),
		40: _water_cells_rotated(
			[&"PURE", &"PURE", &"WATER_INNER_BOTTOM", &"WATER_INNER_BOTTOM"],
			[0, 0, 1, 0]
		),
		41: _water_cells_rotated(
			[&"SHORE_TOP", &"SHORE_TOP", &"WATER_INNER_BOTTOM", &"WATER_INNER_BOTTOM"],
			[0, 0, 1, 0]
		),
		65: _water_cells(&"SHORE_TOP_LEFT", &"SHORE_TOP", &"WATER_TOP_LEFT", &"WATER_TOP"),
		66: _water_cells_rotated(
			[&"SHORE_SIDE", &"SHORE_INNER_RIGHT", &"SHORE_SIDE", &"PURE"],
			[2, 0, 2, 0]
		),
		68: _water_cells_rotated(
			[&"SHORE_SIDE", &"SHORE_SIDE", &"SHORE_SIDE", &"SHORE_SIDE"],
			[2, 0, 2, 0]
		),
		69: _water_cells_rotated(
			[&"SHORE_TOP_LEFT", &"SHORE_TOP_RIGHT", &"SHORE_SIDE", &"SHORE_SIDE"],
			[0, 0, 2, 0]
		),
		72: _water_cells_rotated(
			[&"SHORE_SIDE", &"PURE", &"SHORE_SIDE", &"WATER_INNER_BOTTOM"],
			[2, 0, 2, 0]
		),
		73: _water_cells_rotated(
			[&"SHORE_TOP_LEFT", &"SHORE_TOP", &"SHORE_SIDE", &"WATER_INNER_BOTTOM"],
			[0, 0, 2, 0]
		),
		82: _water_cells_rotated(
			[&"SHORE_SIDE", &"SHORE_INNER_RIGHT", &"SHORE_BOTTOM_CORNER", &"SHORE_SIDE"],
			[2, 0, 1, 1]
		),
		84: _water_cells_rotated(
			[&"SHORE_SIDE", &"SHORE_SIDE", &"SHORE_BOTTOM_CORNER", &"SHORE_BOTTOM_CORNER"],
			[2, 0, 1, 0]
		),
		85: _water_cells_rotated(
			[&"SHORE_TOP_RIGHT", &"SHORE_TOP_RIGHT", &"SHORE_TOP_RIGHT", &"SHORE_TOP_RIGHT"],
			[3, 0, 2, 1]
		),
		128: _water_cells(&"SHORE_INNER_LEFT", &"PURE", &"WATER_INNER_LEFT", &"PURE"),
		130: _water_cells(&"SHORE_INNER_LEFT", &"SHORE_INNER_RIGHT", &"PURE", &"PURE"),
		132: _water_cells(&"SHORE_INNER_LEFT", &"SHORE_SIDE", &"WATER_INNER_LEFT", &"SHORE_SIDE"),
		136: _water_cells(&"SHORE_INNER_LEFT", &"PURE", &"WATER_INNER_LEFT", &"WATER_INNER_BOTTOM"),
		144: _water_cells_rotated(
			[&"SHORE_INNER_LEFT", &"PURE", &"SHORE_SIDE", &"SHORE_SIDE"],
			[0, 0, 1, 1]
		),
		146: _water_cells_rotated(
			[&"SHORE_INNER_LEFT", &"SHORE_INNER_RIGHT", &"SHORE_SIDE", &"SHORE_SIDE"],
			[0, 0, 1, 1]
		),
		148: _water_cells_rotated(
			[&"SHORE_INNER_LEFT", &"SHORE_SIDE", &"SHORE_SIDE", &"SHORE_BOTTOM_CORNER"],
			[0, 0, 1, 0]
		),
		170: _water_cells_rotated(
			[&"SHORE_INNER_RIGHT", &"SHORE_INNER_RIGHT", &"SHORE_INNER_RIGHT", &"SHORE_INNER_RIGHT"],
			[3, 0, 2, 1]
		),
	}

	return {
		"terrain_id": TERRAIN_WATER,
		"name": &"WATER",
		"kind": &"WATER_SHORE",
		"roles": roles,
		"forms": forms,
	}


static func _water_cells(
	top_left: StringName,
	top_right: StringName,
	bottom_left: StringName,
	bottom_right: StringName
) -> Array:
	return [
		_water_cell(top_left, 0),
		_water_cell(top_right, 0),
		_water_cell(bottom_left, 0),
		_water_cell(bottom_right, 0),
	]


static func _water_cells_rotated(roles: Array, rotations: Array) -> Array:
	var result: Array = []
	for index in range(4):
		result.append(_water_cell(roles[index], rotations[index]))
	return result


static func _water_cell(role: StringName, rotation: int) -> Dictionary:
	return {
		"role": role,
		"rotation": rotation % 4,
	}


static func _candidate(atlas: Vector2i, rotation: int, weight: int) -> Dictionary:
	return {
		"atlas": atlas,
		"rotation": rotation % 4,
		"weight": weight,
	}


static func _append_four_rotations(candidates: Array, atlas: Vector2i, weight: int) -> void:
	for rotation in range(4):
		candidates.append(_candidate(atlas, rotation, weight))


static func _validate_candidates(
	candidates_value: Variant,
	location: String,
	errors: PackedStringArray
) -> void:
	if not candidates_value is Array:
		errors.append("%s 不是候选数组。" % location)
		return
	var candidates: Array = candidates_value
	if candidates.is_empty():
		errors.append("%s 没有候选格子。" % location)
		return

	for candidate_index in range(candidates.size()):
		var candidate: Dictionary = candidates[candidate_index]
		var atlas: Vector2i = candidate["atlas"]
		var rotation: int = candidate["rotation"]
		var weight: int = candidate["weight"]
		if atlas.x < 0 or atlas.y < 0 or atlas.x >= ATLAS_GRID_SIZE.x or atlas.y >= ATLAS_GRID_SIZE.y:
			errors.append(
				"%s[%d] 的 atlas=%s 超出 %s。" % [location, candidate_index, atlas, ATLAS_GRID_SIZE]
			)
		if rotation < 0 or rotation > 3:
			errors.append("%s[%d] 的 rotation=%d 不在 0..3。" % [location, candidate_index, rotation])
		if weight <= 0:
			errors.append("%s[%d] 的 weight=%d 必须大于 0。" % [location, candidate_index, weight])
