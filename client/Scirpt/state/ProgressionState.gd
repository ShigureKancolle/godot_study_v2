extends RefCounted
class_name ProgressionState

const GameProto = preload("res://Scirpt/proto/game_proto.gd")

var entity_id: String = ""

var total_exp: float = 0.0
var level: int = 1

static func from_progression_info(progression_info: GameProto.ProgressionEntityInfo) -> ProgressionState:
	var state = ProgressionState.new()
	state.entity_id = progression_info.get_entity_id()
	state.total_exp = progression_info.get_total_exp()
	state.level = progression_info.get_level()
	return state