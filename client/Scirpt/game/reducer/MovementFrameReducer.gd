extends ClientReducerBase
class_name MovementFrameReducer
## 将 WorldFrame 中的移动增量应用到已有 EntityState，不操作表现节点。

static func apply_by_world_frame(store: GameStore, frame: GameProto.WorldFrame) -> Array[EntityState]:
	var changed_states: Array[EntityState] = []
	for move_entry: GameProto.MovementEntry in frame.get_movements():
		# 移动实体
		var state := _apply_MovementEntry(store, move_entry)
		if state == null:
			continue
		changed_states.append(state)
	return changed_states


static func _apply_MovementEntry(store: GameStore, move_entry: GameProto.MovementEntry) -> EntityState:
	var entity_id: String = move_entry.get_entity_id()
	var state := store.get_entity(entity_id)
	if state == null:
		return null
	
	state.server_position = Vector2(move_entry.get_x(), move_entry.get_y())
	state.anim_state = move_entry.get_anim_state()
	state.moving = move_entry.get_moving()
	state.facing_dir = Vector2(move_entry.get_facing_x(), move_entry.get_facing_y())
	return state
