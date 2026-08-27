extends EntityViewPresenter
class_name AnimationPresenter

static var presenter_name := &"AnimationPresenter"


var _facing_dir: String = "Down"
var _current_state: String = "idle"


func update_facing(dir: Vector2):
	# print("[AnimationPresenter]  update_facing: %f %f" % [dir.x, dir.y])
	if dir.is_equal_approx(Vector2.ZERO):
		return

	_facing_dir = _move_dir_to_facing(dir)
	_play_current()

func _move_dir_to_facing(dir: Vector2) -> String:
	# 根据移动方向判断 facing 方向
	var a: float = dir.angle()
	# 四象限判定(以 ±45° 为分界):
	#   [-45°, 45°)               → Right
	#   [45°, 135°)               → Down
	#   [135°, 180°) ∪ [-180°, -135°) → Left
	#   [-135°, -45°)             → Up
	var dir_str := "None"
	if a >= -PI / 4 and a < PI / 4:
		dir_str = "Right"
	elif a >= PI / 4 and a < 3 * PI / 4:
		dir_str = "Down"
	elif a >= 3 * PI / 4 or a < -3 * PI / 4:
		dir_str = "Left"
	else:
		dir_str = "Up"

	print("[AnimationPresenter]  dir: " + dir_str)
	return dir_str

func play_anim(anim_name: String = "idle") -> void:
	# 缓存当前状态名,facing 变化时要用它拼新方向动画
	_current_state = anim_name
	_play_current()

func _play_current() -> void:
	var full_name: String = _facing_dir + "_" + _current_state.capitalize()
	# 防御:SpriteFrames 里没配的动画名会告警
	if _entity_view.entity_visual.has_animation(full_name):
		# 避免重复播放当前动画(AnimatedSprite2D.play 同名动画会从头开始,这里只想继续)
		_entity_view.entity_visual.play_anim(full_name, false)
	else:
		push_warning("PlayerVisual: 动画不存在: " + full_name)
