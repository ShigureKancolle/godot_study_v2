extends Node2D
class_name EntityView

const LOCAL_PLAYER_CONTROLLER_SCRIPT := preload("res://Scirpt/game/controller/LocalPlayerController.gd")

var entity_visual: PlayerVisual = null
var local_player_controller: LocalPlayerController = null
var entity_id: String = ""

var _presenter: Dictionary[StringName, EntityViewPresenter] = {}

func add_presenter(presenter_name: StringName, presenter: EntityViewPresenter):
	if presenter_name and presenter_name not in _presenter:
		_presenter[presenter_name] = presenter

func get_presenter(presenter_name: StringName) -> EntityViewPresenter:
	return _presenter.get(presenter_name, null)

func _process(delta: float):
	for presenter in _presenter.values():
		presenter.process(delta)

	var move_dir = get_presenter(MotionPresenter.presenter_name).get_visual_move_direction()
	get_presenter(AnimationPresenter.presenter_name).update_facing(move_dir)

func setup(entity_state: EntityState):
	entity_id = entity_state.entity_id
	get_presenter(MotionPresenter.presenter_name).set_position(entity_state.server_position)
	get_presenter(AnimationPresenter.presenter_name).update_facing(entity_state.facing_dir)
	get_presenter(NameplatePresenter.presenter_name).set_view_name(entity_state.player_name, entity_state.is_local_player)
	var combat_state = entity_state.combat_entity_state
	if combat_state:
		get_presenter(CombatPresenter.presenter_name).setup(combat_state)
	__setup(entity_state)

func __setup(entity_state: EntityState):
	pass

func dispose():
	pass

func apply_attack_start(attack_id: int, atk_facing: float):
	get_presenter(CombatPresenter.presenter_name).apply_attack_start(attack_id, atk_facing)

func apply_aims_changed(aims_state: EntityState):
	get_presenter(CombatPresenter.presenter_name).apply_atk_facing(aims_state.combat_entity_state.atk_facing)

func apply_atk_rotate(facing: float):
	get_presenter(CombatPresenter.presenter_name).apply_atk_facing(facing)

func apply_movement(state: EntityState) -> void:
	get_presenter(MotionPresenter.presenter_name).set_target_position(state.server_position)
	get_presenter(AnimationPresenter.presenter_name).play_anim(state.anim_state)

func apply_animation(state: EntityState) -> void:
	get_presenter(AnimationPresenter.presenter_name).play_anim(state.anim_state)

func apply_state(state: EntityState) -> void:
	apply_movement(state)

func apply_combat(state: CombatEntityState) -> void:
	if not state:
		return
	apply_atk_rotate(state.atk_facing)
