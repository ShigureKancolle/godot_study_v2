extends Node2D
class_name EntityView

const LOCAL_PLAYER_CONTROLLER_SCRIPT := preload("res://Scirpt/game/controller/LocalPlayerController.gd")

var entity_visual: PlayerVisual = null
var local_player_controller: LocalPlayerController = null
var entity_id: String = ""
var motion_presenter: MotionPresenter = null
var animation_presenter: AnimationPresenter = null
var nameplate_presenter: NameplatePresenter = null

var _presenter: Dictionary[String, EntityViewPresenter] = {}

func add_presenter(presenter: EntityViewPresenter):
	if presenter.name not in _presenter:
		_presenter[presenter.name] = presenter

func get_presenter(name: String) -> EntityViewPresenter:
	return _presenter[name]

func _process(delta: float):
	for presenter in _presenter.values():
		presenter.process(delta)

	var move_dir = motion_presenter.get_visual_move_direction()
	animation_presenter.update_facing(move_dir)

func setup(entity_state: EntityState):
	entity_id = entity_state.entity_id
	motion_presenter.set_position(entity_state.position)
	animation_presenter.update_facing(Vector2.DOWN)
	nameplate_presenter.set_name(entity_state.player_name, entity_state.is_local_player)
	__setup(entity_state)

func __setup(entity_state: EntityState):
	pass

# func apply_state(entity_state: EntityState):
# 	motion_presenter.set_target_position(entity_state.position)

func dispose():
	pass

func apply_movement(state: EntityState) -> void:
	motion_presenter.set_target_position(state.server_position)
	animation_presenter.play_anim(state.anim_state)

func apply_animation(state: EntityState) -> void:
	animation_presenter.play_anim(state.anim_state)