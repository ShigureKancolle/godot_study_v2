extends RefCounted
class_name GameStore

# 服务端world镜像

var server_tick: int = 0
var map_id: String = ""
var self_entity_id: String = ""
var room_id: String = ""
var entities: Dictionary[String, EntityState] = {}

func get_entity(entity_id: String) -> EntityState:
	return entities.get(entity_id)

func add_entity(entity_id: String, state: EntityState):
	entities[entity_id] = state
	
func remove_entity(entity_id: String):
	entities.erase(entity_id)

func all_entities():
	return entities.values()

func clear() -> void:
	room_id = ""
	entities.clear()
