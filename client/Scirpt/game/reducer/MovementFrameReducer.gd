extends Object
class_name MovementFrameReducer

const GameProto = preload("res://Scirpt/proto/game_proto.gd")

static func apply(store: GameStore, frame: GameProto.MovementFrame) -> Array[EntityState]:
	var changed_states: Array[EntityState] = []
	for entry in frame.get_entries():
		var entity_id: String = entry.get_entity_id()
		var state := store.get_entity(entity_id)

		if state == null:
			continue

		state.server_position = Vector2(entry.get_x(), entry.get_y())

		state.moving = entry.get_moving()

		changed_states.append(state)

	store.server_tick = max(store.server_tick, frame.get_server_tick())

	
	return changed_states
