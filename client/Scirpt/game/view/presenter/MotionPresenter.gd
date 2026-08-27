extends EntityViewPresenter
class_name MotionPresenter  

static var presenter_name := &"MotionPresenter"


const POSITION_LERP_SPEED := 15.0

var target_position: Vector2 = Vector2.ZERO

func process(delta: float):
	var alpha: float = min(delta * POSITION_LERP_SPEED, 1.0)

	_entity_view.position = _entity_view.position.lerp(target_position, alpha)

func set_target_position(pos: Vector2):
	# 目标位置，用于插值
	target_position = pos

func set_position(pos: Vector2):
	# 权威值， 设置了就直接跳转到目标位置，不进行插值
	_entity_view.position = pos
	target_position = pos

func get_visual_move_direction():
	# 获取视觉移动方向
	var move_dir = target_position - _entity_view.position
	if move_dir.distance_to(Vector2.ZERO) < 0.01:
		target_position = _entity_view.position
		return Vector2.ZERO
	else:
		return move_dir.normalized()
