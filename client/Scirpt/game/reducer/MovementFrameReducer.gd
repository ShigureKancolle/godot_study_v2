extends ClientReducerBase
class_name MovementFrameReducer
## 将 MovementFrame 应用到已有 EntityState，不操作表现节点。

# const GameProto = preload("res://Scirpt/proto/game_proto.gd")

static func apply(store: GameStore, frame: GameProto.MovementFrame) -> Array[EntityState]:
	var changed_states: Array[EntityState] = []
	for entry in frame.get_entries():
		var entity_id: String = entry.get_entity_id()
		var state := store.get_entity(entity_id)

		if state == null:
			continue

		state.server_position = Vector2(entry.get_x(), entry.get_y())
		state.anim_state = entry.get_anim_state()
		state.moving = entry.get_moving()
		state.facing_dir = Vector2(entry.get_facing_x(), entry.get_facing_y())
		changed_states.append(state)

	store.server_tick = max(store.server_tick, frame.get_server_tick())

	
	return changed_states

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
