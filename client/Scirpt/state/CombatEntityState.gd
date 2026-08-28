extends RefCounted
class_name CombatEntityState

const GameProto = preload("res://Scirpt/proto/game_proto.gd")


var entity_id: String = ""
var hp: int = 0
var max_hp: int = 0
var dead: bool = false
var atk_facing: float = 0.0


static func from_entity_info(entity_info: GameProto.CombatEntityInfo) -> CombatEntityState:
	var state = CombatEntityState.new()
	state.entity_id = entity_info.get_entity_id()
	# state.hp = entity_info.get_hp()
	# state.max_hp = entity_info.get_max_hp()
	# state.dead = entity_info.get_dead()
	state.atk_facing = entity_info.get_atk_facing()
	return state
