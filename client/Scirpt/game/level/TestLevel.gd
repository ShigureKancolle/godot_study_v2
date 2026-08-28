extends Node2D
class_name TestLevel
const LEVEL_SCENE := preload("res://Prefab/Level/TestLevel.tscn")

@onready var entity: Node2D = $Entity
@onready var hud: Node2D = $Hud
@onready var debug: Node2D = $Debug
@onready var map: Node2D = $Map

var entity_views: Dictionary = {}
# 现在只有一个关卡 先不搞mgr 用静态方法
static func create_level():
	return LEVEL_SCENE.instantiate()

func _ready():
	var store = GameBootstrap.game_store

	for state: EntityState in store.all_entities():
		spawn_entity(state)

	SignalMgr.Get().snl_entities_moved.connect(hdl_entities_moved)
	SignalMgr.Get().snl_attack_start.connect(hdl_attack_start)
	SignalMgr.Get().snl_entity_added.connect(spawn_entity)
	SignalMgr.Get().snl_entity_removed.connect(remove_entity)
	SignalMgr.Get().snl_entity_updated.connect(update_entity)
	SignalMgr.Get().snl_store_cleared.connect(clear_entity_views)
	SignalMgr.Get().snl_entities_combat.connect(hdl_entities_combat)


func spawn_entity(entity_state: EntityState):
	if entity_state.entity_id in entity_views:
		return

	var view = EntityViewFactory.create_entity_view(entity_state)
	if not view:
		print("[TestLevel] create entity view failed")
		return
	entity.add_child(view)
	view.setup(entity_state)
	entity_views[entity_state.entity_id] = view

func update_entity(entity_state: EntityState):
	var view = entity_views.get(entity_state.entity_id, null)
	if view:
		view.apply_state(entity_state)

func remove_entity(entity_id: String):
	var view = entity_views.get(entity_id, null)
	if view:
		entity_views.erase(entity_id)
		entity.remove_child(view)
		view.queue_free()

func hdl_entities_moved(change_states: Array[EntityState]):
	for entity_state in change_states:
		if entity_state.entity_id in entity_views:
			entity_views[entity_state.entity_id].apply_movement(entity_state)

func hdl_attack_start(attacker_id: String, attack_id: int, atk_facing: float):
	print("[TestLevel] attack start: ", attacker_id, " ", attack_id)
	var entity_view = entity_views.get(attacker_id, null)
	if entity_view:
		entity_view.apply_attack_start(attack_id, atk_facing)

func hdl_entities_combat(change_states: Array[EntityState]):
	for entity_state in change_states:
		if entity_state.entity_id in entity_views:
			entity_views[entity_state.entity_id].apply_combat(entity_state.combat_entity_state)

func clear_entity_views():
	for view in entity_views.values():
		if is_instance_valid(view):
			view.queue_free()

	entity_views.clear()

func _exit_tree():
	if SignalMgr.Get().snl_store_cleared.is_connected(clear_entity_views):
		SignalMgr.Get().snl_store_cleared.disconnect(clear_entity_views)
