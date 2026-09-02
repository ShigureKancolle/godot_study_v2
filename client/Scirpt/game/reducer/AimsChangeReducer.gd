extends ClientReducerBase
class_name AimsChangeReducer
static func apply_by_world_frame(store: GameStore, frame: GameProto.WorldFrame) -> Array[EntityState]:
	var changed_states: Array[EntityState] = []
	for aim_state_delta in frame.get_aims():
		var state := _apply_aim_state_delta(store, aim_state_delta)
		if state != null:
			changed_states.append(state)

	return changed_states
	
static func _apply_aim_state_delta(store: GameStore, aim_state: GameProto.AimStateDelta) -> EntityState:
	var entity_id: String = aim_state.get_entity_id()
	var state := store.get_entity(entity_id)
	if state == null:
		return null

	var combat_state := state.combat_entity_state
	if combat_state == null:
		return null
	combat_state.atk_facing = aim_state.get_atk_facing()
	return state
