extends Node
class_name LocalPlayerController
## 采集本地输入，只在意图变化时发送 MoveIntent。

var entity_id: String = ""
var _last_direction: Vector2 = Vector2.ZERO
var _last_moving: bool = false

func setup(target_entity_id: String):
	self.entity_id = target_entity_id

func _process(delta: float):
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var moving = dir != Vector2.ZERO

	if (moving == _last_moving and dir.is_equal_approx(_last_direction)):
		# 起步 停止 方向变化才通知服务端
		return

	WebSocketMgr.Get().send("move_intent", {
		"entity_id": self.entity_id,
		"dir_x": dir.x,
		"dir_y": dir.y,
		"moving": moving
	})

	_last_direction = dir
	_last_moving = moving

	
