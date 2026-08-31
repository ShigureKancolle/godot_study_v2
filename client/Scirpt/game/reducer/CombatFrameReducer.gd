extends ClientReducerBase
class_name CombatFrameReducer

# static func apply(store: GameStore, frame: GameProto.CombatFrame) -> Array[EntityState]:
# 	var changed_states: Array[EntityState] = []
# 	for entry in frame.get_combats():
# 		var entity_id: String = entry.get_entity_id()
# 		var state := store.get_entity(entity_id)
# 		if state == null:
# 			continue
# 		var combat_state := state.combat_entity_state
# 		if combat_state == null:
# 			continue
# 		combat_state.atk_facing = entry.get_atk_facing()
# 		changed_states.append(state)

# 	store.server_tick = frame.get_server_tick()
# 	return changed_states

static func apply_by_world_frame(store: GameStore, frame: GameProto.WorldFrame) -> Array[EntityState]:
	var changed_states: Array[EntityState] = []
	for aim_state_delta in frame.get_anims():
		var state := _apply_AnimStateDelta(store, aim_state_delta)
		if state != null:
			changed_states.append(state)

	return changed_states
	
static func _apply_AnimStateDelta(store: GameStore, combat_entry: GameProto.AnimStateDelta) -> EntityState:
	var entity_id: String = combat_entry.get_entity_id()
	var state := store.get_entity(entity_id)
	if state == null:
		return null

	var combat_state := state.combat_entity_state
	if combat_state == null:
		return null
	combat_state.atk_facing = combat_entry.get_atk_facing()
	return state
	
	
