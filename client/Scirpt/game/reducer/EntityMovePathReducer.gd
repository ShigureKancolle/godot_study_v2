extends ClientReducerBase
class_name EntityMovePathReducer

static func apply_by_world_frame(store: GameStore, frame: GameProto.WorldFrame) -> Array[EntityMovePathState]:
	var changes: Array[EntityMovePathState] = []
	for move_path_info: GameProto.EntityMovePath in frame.get_entity_move_path():
		var state := _apply_move_path_delta(store, move_path_info)
		if state != null:
			changes.append(state)

	return changes

static func _apply_move_path_delta(store: GameStore, move_path_info: GameProto.EntityMovePath) -> EntityMovePathState:
	var entity_state := store.get_entity(move_path_info.get_entity_id())
	if entity_state == null:
		return null

	var move_path_state := entity_state.entity_move_path
	if move_path_state == null:
		move_path_state = EntityMovePathState.new()
		entity_state.entity_move_path = move_path_state

	move_path_state.apply_proto(move_path_info)
	return move_path_state
