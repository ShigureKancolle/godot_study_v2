extends RefCounted
class_name GameStore


# signal entity_added(entity: EntityState)
# signal entity_updated(entity: EntityState)
# signal entity_removed(entity_id: String)
# signal store_cleared

var room_id: String = ""
var entities: Dictionary[String, EntityState] = {}

func get_entity(entity_id: String) -> EntityState:
	return entities.get(entity_id)


func clear() -> void:
	room_id = ""
	entities.clear()
	# store_cleared.emit()
