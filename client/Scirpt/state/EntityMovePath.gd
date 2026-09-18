extends RefCounted
class_name EntityMovePathState

const GameProto = preload("res://Scirpt/proto/game_proto.gd")

var entity_id: String = ""
var path: Array[Vector2] = []
var path_index: int = 0
var target_id: String = ""

static func from_proto(move_path_info: GameProto.EntityMovePath) -> EntityMovePathState:
	var state := EntityMovePathState.new()
	state.apply_proto(move_path_info)
	return state

func apply_proto(move_path_info: GameProto.EntityMovePath) -> void:
	entity_id = move_path_info.get_entity_id()
	path.clear()
	for point_info in move_path_info.get_path():
		path.append(Vector2(point_info.get_x(), point_info.get_y()))
	path_index = int(move_path_info.get_path_index())
	target_id = move_path_info.get_target_id()

