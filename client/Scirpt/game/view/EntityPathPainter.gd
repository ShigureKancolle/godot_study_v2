extends Node2D
class_name EntityPathPainter
## 在关卡 Debug 节点的世界坐标系中绘制怪物剩余路径。

var _start_position: Vector2 = Vector2.ZERO
var _path: Array[Vector2] = []
var _path_idx: int = 0

func set_path(path: Array[Vector2], path_idx: int) -> void:
	_path = path
	_path_idx = path_idx
	queue_redraw()

func set_start_position(start_position: Vector2) -> void:
	if _start_position.is_equal_approx(start_position):
		return
	_start_position = start_position
	queue_redraw()

func _draw() -> void:
	if _path_idx >= _path.size():
		return
	var left_path: Array[Vector2] = [_start_position]
	for index in range(_path_idx, _path.size()):
		left_path.append(_path[index])
	_draw_path(left_path)

func _draw_path(path: Array[Vector2]) -> void:
	for index in range(path.size() - 1):
		draw_line(path[index], path[index + 1], Color(1, 0, 0, 1), 12, false)

