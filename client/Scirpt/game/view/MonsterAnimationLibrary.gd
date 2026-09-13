extends RefCounted
class_name MonsterAnimationLibrary
## 从逐帧区域构建四方向、五种状态的动画；只配置 AtlasTexture，不修改原图。

const STATES: Array[String] = ["Idle", "Run", "Attack", "Hurt", "Die"]
const DIRECTIONS: Array[String] = ["Down", "Right", "Up", "Left"]
static var _frames_cache: Dictionary = {}

static func build(visual: Dictionary, death_duration_ms: int) -> SpriteFrames:
	var path: String = visual.get("sprite_sheet", "")
	var cache_key: String = "%s:%d" % [path, death_duration_ms]
	if _frames_cache.has(cache_key):
		return _frames_cache[cache_key]
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		push_error("怪物动画图集加载失败: " + path)
		return null
	var columns: int = int(visual.get("columns", 8))
	var rows: int = int(visual.get("rows", 10))
	if columns != 8 or rows != 10:
		push_error("怪物图集必须使用八列十行布局: " + path)
		return null
	var metadata_path: String = visual.get("atlas_metadata", "")
	var metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	if not metadata is Dictionary or metadata.get("regions", []).size() != 80:
		push_error("怪物动画必须提供八十帧裁切区域: " + metadata_path)
		return null
	var canvas := Vector2(metadata.canvas_size[0], metadata.canvas_size[1])
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for state_index in range(STATES.size()):
		for direction_index in range(DIRECTIONS.size()):
			var animation_name := StringName(DIRECTIONS[direction_index] + "_" + STATES[state_index])
			frames.add_animation(animation_name)
			frames.set_animation_loop(animation_name, state_index <= 1)
			var fps: float = 6.0 if state_index == 0 else 10.0
			if state_index == 3:
				fps = 20.0
			if state_index == 4:
				# 提前一帧结束，确保服务端移除前已经呈现最终死亡姿势。
				fps = 4.0 / maxf(float(death_duration_ms - 34) / 1000.0, 0.1)
			frames.set_animation_speed(animation_name, fps)
			var row: int = state_index * 2 + int(direction_index / 2)
			var first_column: int = (direction_index % 2) * 4
			for frame_index in range(4):
				var column: int = first_column + frame_index
				var region: Array = metadata.regions[row * columns + column]
				var size := Vector2(region[2], region[3])
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(Vector2(region[0], region[1]), size)
				# 四方向共用画布和脚底线，避免图集留白不均造成画面抖动。
				atlas.margin = Rect2(Vector2((canvas.x - size.x) * 0.5, canvas.y - size.y - 4.0), canvas - size)
				atlas.filter_clip = true
				frames.add_frame(animation_name, atlas)
	_frames_cache[cache_key] = frames
	return frames
