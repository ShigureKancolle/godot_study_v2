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
	view.add_presenter(motion_presenter)
	view.add_presenter(animation_presenter)
	view.add_presenter(nameplate_presenter)

	view.setup(entity_state)
	return view
