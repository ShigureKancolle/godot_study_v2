extends Node2D
class_name TestLevel
const LEVEL_SCENE := preload("res://Prefab/Level/TestLevel.tscn")

@onready var entity: Node2D = $Entity
@onready var hud: Node2D = $Hud
@onready var debug: Node2D = $Debug
@onready var map: Node2D = $Map
@onready var effect_parent: Node2D = $Effect
@onready var damage_num_parent: Node2D = $DamageNum

var entity_views: Dictionary[String, EntityView] = {}
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
	SignalMgr.Get().snl_entities_aims_changed.connect(hdl_entities_aims_changed)
	SignalMgr.Get().snl_entities_health_changed.connect(hdl_entities_health_changed)
	# SignalMgr.Get().snl_entities_mp_changed.connect(hdl_entities_mp_changed)
	SignalMgr.Get().snl_damage_received.connect(hdl_damage_received)
	SignalMgr.Get().snl_entity_dead.connect(hdl_entity_dead)


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

func hdl_entities_aims_changed(change_states: Array[EntityState]):
	for entity_state in change_states:
		if entity_state.entity_id in entity_views:
			entity_views[entity_state.entity_id].apply_aims_changed(entity_state)

func hdl_entities_health_changed(change_states: Array[EntityState]):
	for entity_state in change_states:
		if entity_state.entity_id in entity_views:
			entity_views[entity_state.entity_id].apply_hp_changed(entity_state)

# func hdl_entities_mp_changed(change_states: Array[EntityState]):
# 	for entity_state in change_states:
# 		if entity_state.entity_id in entity_views:
# 			entity_views[entity_state.entity_id].apply_mp_changed(entity_state)

func hdl_damage_received(attacker_id: String, target_id: String, attack_id: int, damage: int, critical: bool):
	var target_view = entity_views.get(target_id, null)
	if not target_view:
		return
	target_view.apply_damage_received(damage)

	# 受击特效
	var hurt_effect = EffectFactory.create_hurt_effect(attack_id)
	if hurt_effect:
		hurt_effect.position = target_view.position
		effect_parent.add_child(hurt_effect)

	# 伤害数字
	var damage_num = EffectFactory.create_damage_num(damage, critical)
	if damage_num:
		var pos = target_view.position + Vector2((randf() - 0.5) * 50, (randf() - 0.5) * 50)
		damage_num.position = pos
		damage_num_parent.add_child(damage_num)

func hdl_entity_dead(entity_id: String):
	var entity_view = entity_views.get(entity_id, null)
	if entity_view:
		entity_view.play_dead_animation()


func clear_entity_views():
	for view in entity_views.values():
		if is_instance_valid(view):
			view.queue_free()

	entity_views.clear()

func _exit_tree():
	if SignalMgr.Get().snl_store_cleared.is_connected(clear_entity_views):
		SignalMgr.Get().snl_store_cleared.disconnect(clear_entity_views)
