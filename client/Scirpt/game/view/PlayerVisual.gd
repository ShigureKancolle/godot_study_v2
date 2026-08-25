extends Node2D
class_name PlayerVisual

@onready var body: AnimatedSprite2D = $Body
@onready var facing_arrow: Sprite2D = $FacingArrow
@onready var name_label: Label = $NameLabel

var entity_state: EntityState = null

func _ready() -> void:
	if entity_state:
		refresh_ui(entity_state)

func set_entity_name(entity_name: String):
	name_label.text = entity_name

func update_facing(facing: int):
	facing_arrow.rotation = facing
	# 根据方向播动画

func _facing_to_dir(facing: int) -> String:
	return ""
	
func setup(state: EntityState):
	entity_state = state
	if is_node_ready():
		refresh_ui(entity_state)

func refresh_ui(entity_state: EntityState):
	var entity_name = entity_state.player_name
	var local_eid = GameBootstrap.game_store.self_entity_id
	if entity_state.entity_id == local_eid:
		entity_name += "(你)"

	set_entity_name(entity_name)
	# body.play(entity_state.anim_state)
	update_facing(entity_state.facing)

func apply_moved(state: EntityState):
	# 改变动画
	pass
