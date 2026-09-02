extends ClientReducerBase
class_name EntitySpawnedReducer

static func apply_by_world_frame(store: GameStore, frame: GameProto.WorldFrame) -> Array[EntityState]:
	var changes: Array[EntityState] = []
	for entity_info: GameProto.EntityInfo in frame.get_spawned_entities():
		# 生成新实体
		var state := EntityState.from_entity_info(entity_info)
		store.add_entity(state.entity_id, state)
		changes.append(state)
	return changes
