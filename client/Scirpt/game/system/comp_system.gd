extends Object
class_name CompSystem

const GameProto = preload("res://Scirpt/proto/game_proto.gd")

# region WorldSnapshotReducer
static func apply_world_snapshot(store: GameStore, snapshot: GameProto.WorldSnapshot):
	store.clear()
	store.room_id = snapshot.get_room_id()
	store.server_tick = snapshot.get_server_tick()
	store.map_id = snapshot.get_map_id()
	store.self_entity_id = snapshot.get_self_entity_id()

	for entity in snapshot.get_entities():
		var state := EntityState.from_entity_info(entity)
		state.server_position = Vector2(entity.get_x(), entity.get_y())
		store.add_entity(state.entity_id, state)
# endregion
