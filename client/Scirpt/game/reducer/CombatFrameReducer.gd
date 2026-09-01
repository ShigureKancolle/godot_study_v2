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


	
