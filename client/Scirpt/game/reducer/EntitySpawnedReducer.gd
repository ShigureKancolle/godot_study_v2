extends ClientReducerBase
class_name EntitySpawnedReducer

static func apply(store: GameStore, entity: GameProto.EntityInfo) -> EntityState:
	var state := EntityState.from_entity_info(entity)
	store.add_entity(state.entity_id, state)
	return state