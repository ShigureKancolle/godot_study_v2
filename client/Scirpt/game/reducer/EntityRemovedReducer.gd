extends ClientReducerBase
class_name EntityRemovedReducer

static func apply(store: GameStore, entity_id: String):
    store.remove_entity(entity_id)
