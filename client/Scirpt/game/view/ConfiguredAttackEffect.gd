extends Node2D
class_name ConfiguredAttackEffect
## 根据权威配置绘制预警、命中闪光与挥击轨迹，绝不自行结算命中或伤害。

signal completed

var attack_config: ConfigLoader.AttackConfig = null
var elapsed_ms: float = 0.0
var enemy_attack: bool = true
var accent: Color = Color("ffb65b")
var _finished: bool = false

func setup(config: ConfigLoader.AttackConfig, is_enemy: bool) -> void:
	attack_config = config
	enemy_attack = is_enemy
	z_index = 2
	if not enemy_attack:
		accent = Color("b2edf7")
	queue_redraw()

func _process(delta: float) -> void:
	if attack_config == null or _finished:
		return
	elapsed_ms += delta * 1000.0
	if elapsed_ms >= attack_config.get_attack_time():
		_finished = true
		completed.emit()
		return
	queue_redraw()

func _draw() -> void:
	if attack_config == null:
		return
	var previous_end: float = 0.0
	for shape: ConfigLoader.AttackShape in attack_config.shape_list:
		if elapsed_ms >= previous_end and elapsed_ms <= shape.duration:
			_draw_shape(shape, previous_end)
		previous_end = float(shape.duration)

func _draw_shape(shape: ConfigLoader.AttackShape, start_ms: float) -> void:
	var before_hit: bool = elapsed_ms < shape.hit_time
	var progress: float = clampf((elapsed_ms - start_ms) / maxf(shape.hit_time - start_ms, 1.0), 0.0, 1.0)
	var after_hit: float = elapsed_ms - shape.hit_time
	var fade: float = clampf(1.0 - after_hit / maxf(shape.duration - shape.hit_time, 1.0), 0.0, 1.0)
	var fill := Color(accent, 0.07 + progress * 0.18) if before_hit else Color(accent, fade * 0.32)
	var edge := Color(accent, 0.5 + progress * 0.45) if before_hit else Color("fff6ce", fade)
	if shape.shape == ConfigLoader.ShapeType_SECTOR:
		var params: ConfigLoader.SectorParams = shape.shape_params
		var half: float = params.angle * 0.5
		var points := PackedVector2Array([Vector2.ZERO])
		for index in range(33):
			var angle: float = lerpf(-half, half, index / 32.0)
			points.append(Vector2.from_angle(angle) * params.radius)
		draw_colored_polygon(points, fill)
		draw_arc(Vector2.ZERO, params.radius, -half, half, 32, edge, 2.0, true)
		draw_line(Vector2.ZERO, Vector2.from_angle(-half) * params.radius, edge, 1.2, true)
		draw_line(Vector2.ZERO, Vector2.from_angle(half) * params.radius, edge, 1.2, true)
		if before_hit:
			draw_arc(Vector2.ZERO, params.radius * progress, -half, half, 24, Color(accent, 0.65), 1.5, true)
		else:
			var slash_progress: float = clampf(after_hit / 150.0, 0.0, 1.0)
			var slash_angle: float = lerpf(-half, half, slash_progress)
			draw_arc(Vector2.ZERO, params.radius * 0.86, maxf(-half, slash_angle - 0.7), slash_angle, 16, edge, 5.0 * fade, true)
	elif shape.shape == ConfigLoader.ShapeType_RECT:
		var params: ConfigLoader.RectParams = shape.shape_params
		var rect := Rect2(params.distance, -params.width * 0.5, params.length, params.width)
		draw_rect(rect, fill)
		draw_rect(rect, edge, false, 1.5)
		if before_hit:
			var line_x: float = params.distance + params.length * progress
			draw_line(Vector2(line_x, -params.width * 0.5), Vector2(line_x, params.width * 0.5), edge, 2.0)
		else:
			draw_line(Vector2(params.distance, 0), Vector2(params.distance + params.length, 0), edge, 4.0 * fade, true)
