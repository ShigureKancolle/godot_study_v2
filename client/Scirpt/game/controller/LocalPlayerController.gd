extends Node
class_name LocalPlayerController
## 采集本地输入，只在意图变化时发送 MoveIntent。

var entity_id: String = ""
var _last_direction: Vector2 = Vector2.ZERO
var _last_moving: bool = false

func setup(target_entity_id: String):
	entity_id = target_entity_id

func _process(delta: float):
	_move_intent(delta)
	_attack_intent(delta)
	_atk_rotate_intent(delta)
	
func _move_intent(_delta: float):
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var moving = dir != Vector2.ZERO

	if (moving == _last_moving and dir.is_equal_approx(_last_direction)):
		# 起步 停止 方向变化才通知服务端
		return

	WebSocketMgr.Get().send("move_intent", {
		"entity_id": entity_id,
		"dir_x": dir.x,
		"dir_y": dir.y,
		"moving": moving
	})

	_last_direction = dir
	_last_moving = moving


func _attack_intent(_delta: float):
	var attack := Input.is_action_just_pressed("atk_left")

	if not attack:
		return

	var attack_id = 1004
	WebSocketMgr.Get().send("attack_intent", {
		"attacker_id": entity_id,
		"attack": attack_id
	})

func _atk_rotate_intent(_delta: float):
	# 获取鼠标位置
	var role := get_parent() as Node2D
	var mouse_pos := role.get_global_mouse_position()
	var entity_pos := role.get_global_position()
	var dir := (mouse_pos - entity_pos).normalized()

	if dir.is_zero_approx():
		return

	var angle := dir.angle_to(Vector2.RIGHT)
	WebSocketMgr.Get().send("atk_rotate_intent", {
		"entity_id": entity_id,
		"angle": angle
	})
