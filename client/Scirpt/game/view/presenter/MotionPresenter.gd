extends RefCounted
class_name MotionPresenter  

const POSITION_LERP_SPEED := 15.0
var entity_view: EntityView = null
var target_position: Vector2 = Vector2.ZERO

func _init(view: EntityView):
	entity_view = view

func process(delta: float):
	var alpha := 1.0 - exp(
		-POSITION_LERP_SPEED * delta
	)

	entity_view.position = entity_view.position.lerp(target_position, alpha)

func set_target_position(pos: Vector2):
	# 目标位置，用于插值
	target_position = pos

func set_position(pos: Vector2):
	# 权威值， 设置了就直接跳转到目标位置，不进行插值
	entity_view.position = pos
	target_position = pos

func get_visual_move_direction():
	# 获取视觉移动方向
	var move_dir = target_position - entity_view.position
	if move_dir.is_equal_approx(Vector2.ZERO):
		return Vector2.ZERO
	else:
		return move_dir.normalized()
