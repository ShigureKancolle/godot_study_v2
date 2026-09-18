extends Node2D
class_name EntityView
## 实体共有表现：位置初始化、移动插值和生命周期，不包含角色能力。

var entity_id: String = ""
var _presenter: Dictionary[StringName, EntityViewPresenter] = {}

func add_presenter(presenter_name: StringName, presenter: EntityViewPresenter):
	# Factory 在创建时装齐依赖；重复注册或空实例属于装配错误。
	assert(not presenter_name.is_empty())
	assert(presenter != null)
	assert(presenter_name not in _presenter)
	_presenter[presenter_name] = presenter

func get_presenter(presenter_name: StringName) -> EntityViewPresenter:
	# 必需的 Presenter 缺失时直接暴露错误，不把装配失败当作可选能力。
	return _presenter[presenter_name]

func _process(delta: float):
	for presenter in _presenter.values():
		presenter.process(delta)

func setup(entity_state: EntityState):
	entity_id = entity_state.entity_id
	get_presenter(MotionPresenter.presenter_name).set_position(entity_state.server_position)

func apply_movement(state: EntityState) -> void:
	get_presenter(MotionPresenter.presenter_name).set_target_position(state.server_position)

func apply_state(state: EntityState) -> void:
	apply_movement(state)

func dispose():
	pass
