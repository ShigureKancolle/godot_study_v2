extends ClientReducerBase
class_name EntityRemovedReducer

static func apply(store: GameStore, entity_id: String):
	store.remove_entity(entity_id)

static func apply_by_world_frame(store: GameStore, frame: GameProto.WorldFrame):
	var removed_entities: Array[String] = []
	for entity_id in frame.get_removed_entity_ids():
		apply(store, entity_id)
		removed_entities.append(entity_id)
	return removed_entities
