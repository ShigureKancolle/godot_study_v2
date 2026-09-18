extends Node2D
class_name EntityMovePathDraw

var _path: Array[Vector2] = []
var _path_idx: int = 0
var _target_id: String = ""

func set_up(path: Array[Vector2], path_idx: int, target_id: String):
	_path = path
	_path_idx = path_idx
	_target_id = target_id
	queue_redraw()


func _draw():
	if _path_idx >= _path.size():
		return

	if _target_id == "":
		return

	var left_path = _path.slice(_path_idx)
	if left_path.size() == 0:
		queue_free()
		return

	var target_entity = GameBootstrap.game_store.get_entity(_target_id)
	if not target_entity:
		return

	var start_pos = target_entity.position
	left_path.insert(0, start_pos)
	_draw_path(left_path)

func _draw_path(path: Array[Vector2]):
	for i in range(path.size() - 1):
		draw_line(path[i], path[i + 1], Color(1, 0, 0, 1), 12, false)


func _process(delta: float):
	if _path_idx >= _path.size():
		return

	if _target_id == "":
		return

	queue_redraw()
