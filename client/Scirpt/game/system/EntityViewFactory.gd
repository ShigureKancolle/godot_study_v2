extends Object
class_name EntityViewFactory
## 根据权威 EntityState 创建对应的表现节点。
const PALYER_VISUAL_SCENE := preload("res://Prefab/Role/PlayerVisual.tscn")

const Role = preload("res://Scirpt/game/view/Role.gd")

static func create_entity_view(entity_state: EntityState):
	if entity_state.entity_type == EntityState.EntityType.PLAYER:
		return create_role_view(entity_state)
	else:
		return null

static func create_role_view(entity_state: EntityState):
	var view = Role.new()
	var view_visual = PALYER_VISUAL_SCENE.instantiate()
	view.add_child(view_visual)
	var motion_presenter = MotionPresenter.new(view)
	var animation_presenter = AnimationPresenter.new(view)
	var nameplate_presenter = NameplatePresenter.new(view)
	view.add_presenter(MotionPresenter.presenter_name, motion_presenter)
	view.add_presenter(AnimationPresenter.presenter_name, animation_presenter)
	view.add_presenter(NameplatePresenter.presenter_name, nameplate_presenter)
	view.entity_visual = view_visual
	
	if entity_state.combat_entity_state:
		var combat_presenter = CombatPresenter.new(view)
		view.add_presenter(CombatPresenter.presenter_name, combat_presenter)

	return view
