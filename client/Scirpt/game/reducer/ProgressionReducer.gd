extends ClientReducerBase
class_name ProgressionReducer

static func apply_by_world_frame(store: GameStore, frame: GameProto.WorldFrame) -> Array[EntityState]:
	var changes :Array[EntityState] = []
	for prog_state in frame.get_progression_state():
		var state = _apply_progression_info(store, prog_state)
		if state != null:
			changes.append(state)
	return changes

static func _apply_progression_info(store: GameStore, prog_delta: GameProto.ProgressionStateDelta) -> EntityState:
	var state := store.get_entity(prog_delta.get_entity_id())
	if state == null:
		return null
	var _prog_state := state.progression_state
	if _prog_state == null:
		return null

	_prog_state.total_exp = prog_delta.get_cur_exp()
	_prog_state.level = prog_delta.get_cur_level()
	return state
