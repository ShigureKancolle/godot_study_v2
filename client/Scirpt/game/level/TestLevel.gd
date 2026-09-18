extends Node2D
class_name TestLevel
const LEVEL_SCENE := preload("res://Prefab/Level/TestLevel.tscn")
const MENU_UI_PATH := "res://Prefab/Level/MenuUI.tscn"
const HUD_MAIN_UI_PATH := "res://Prefab/Hud/HudMain.tscn"

@onready var hud_ui_root: Control = $TestLevelUI/HudUI
@onready var menu_ui_root: Control = $TestLevelUI/MenuUI
@onready var test_level_ui: CanvasLayer = $TestLevelUI
@onready var entity: Node2D = $Entity
@onready var hud: Node2D = $Hud
@onready var debug: Node2D = $Debug
@onready var map: Node2D = $Map
@onready var effect_parent: Node2D = $Effect
@onready var damage_num_parent: Node2D = $DamageNum

var tile_map_layer: TileMapLayer = null
var entity_views: Dictionary[String, EntityView] = {}
var menu_ui: Node2D = null
var hud_main_ui: Control = null
var entity_path_painter: Dictionary[String, EntityPathPainter] = {}


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
	SignalMgr.Get().snl_entities_prog_changed.connect(hdl_entities_prog_changed)
	# SignalMgr.Get().snl_entities_mp_changed.connect(hdl_entities_mp_changed)
	SignalMgr.Get().snl_damage_received.connect(hdl_damage_received)
	SignalMgr.Get().snl_entity_dead.connect(hdl_entity_dead)
	SignalMgr.Get().snl_entity_upgrade.connect(hdl_entity_upgrade)
	SignalMgr.Get().snl_entity_path_draw.connect(hdl_entity_path_draw)
	SignalMgr.Get().snl_entities_move_paths_changed.connect(hdl_entities_move_paths_changed)
		

	# 初始化地图
	tile_map_layer = NavigationMapView.new()
	map.add_child(tile_map_layer)
	
	# hud main ui
	hud_main_ui = load(HUD_MAIN_UI_PATH).instantiate()
	hud_ui_root.add_child(hud_main_ui)
	

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("esc_menu") and not event.is_echo():
		# 打开菜单界面
		if menu_ui == null:
			menu_ui = load(MENU_UI_PATH).instantiate()
			menu_ui_root.add_child(menu_ui)
			menu_ui.show()
		else:
			if menu_ui.is_visible():
				menu_ui.hide()
			else:
				menu_ui.show()
				
		# send_pause_game(is_pause())

func is_pause() -> bool:
	if menu_ui == null:
		return false
	return menu_ui.is_visible()

func send_pause_game(pause):
	WebSocketMgr.Get().send("pause_game_world", {
		"pause": pause
	})

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
	remove_entity_path_painter(entity_id)

func hdl_entities_moved(change_states: Array[EntityState]):
	for entity_state in change_states:
		if entity_state.entity_id in entity_views:
			entity_views[entity_state.entity_id].apply_movement(entity_state)

func hdl_attack_start(attacker_id: String, attack_id: int, atk_facing: float):
	print("[TestLevel] attack start: ", attacker_id, " ", attack_id)
	var entity_view := entity_views.get(attacker_id) as Role
	if entity_view:
		entity_view.apply_attack_start(attack_id, atk_facing)

func hdl_entities_aims_changed(change_states: Array[EntityState]):
	for entity_state in change_states:
		var role := entity_views.get(entity_state.entity_id) as Role
		if role != null:
			role.apply_aims_changed(entity_state)

func hdl_entities_health_changed(change_states: Array[EntityState]):
	for entity_state in change_states:
		var role := entity_views.get(entity_state.entity_id) as Role
		if role != null:
			role.apply_hp_changed(entity_state)

func hdl_entities_prog_changed(change_states: Array[EntityState]):
	for entity_state in change_states:
		var player := entity_views.get(entity_state.entity_id) as PlayerRole
		if player != null:
			player.apply_prog_changed(entity_state)

# func hdl_entities_mp_changed(change_states: Array[EntityState]):
# 	for entity_state in change_states:
# 		if entity_state.entity_id in entity_views:
# 			entity_views[entity_state.entity_id].apply_mp_changed(entity_state)

func hdl_entity_upgrade(entity_id: String, pre_level: int, cur_level: int):
	# 还没想好升级发什么特效
	pass

func hdl_damage_received(attacker_id: String, target_id: String, attack_id: int, damage: int, critical: bool):
	var target_view := entity_views.get(target_id) as Role
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
	var entity_view := entity_views.get(entity_id) as Role
	if entity_view:
		entity_view.play_dead_animation()

func hdl_entity_path_draw(entity_id: String, draw_path: bool):
	var monster := entity_views.get(entity_id) as MonsterRole
	if monster == null:
		return

	var painter := entity_path_painter.get(entity_id) as EntityPathPainter
	if draw_path and painter == null:
		painter = EntityPathPainter.new()
		debug.add_child(painter)
		entity_path_painter[entity_id] = painter
		monster.set_path_painter(painter)

	monster.set_move_path_visible(draw_path)

func hdl_entities_move_paths_changed(change_states: Array[EntityMovePathState]):
	for path_state in change_states:
		var monster := entity_views.get(path_state.entity_id) as MonsterRole
		if monster != null:
			monster.apply_move_path_changed(path_state)

func remove_entity_path_painter(entity_id: String) -> void:
	var painter := entity_path_painter.get(entity_id) as EntityPathPainter
	if painter == null:
		return
	entity_path_painter.erase(entity_id)
	painter.queue_free()

func clear_entity_views():
	for view in entity_views.values():
		if is_instance_valid(view):
			view.queue_free()

	entity_views.clear()
	for painter in entity_path_painter.values():
		if is_instance_valid(painter):
			painter.queue_free()
	entity_path_painter.clear()

func _exit_tree():
	if SignalMgr.Get().snl_store_cleared.is_connected(clear_entity_views):
		SignalMgr.Get().snl_store_cleared.disconnect(clear_entity_views)
