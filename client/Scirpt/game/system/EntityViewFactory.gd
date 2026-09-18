extends Object
class_name EntityViewFactory
## 根据权威 EntityState 创建对应的表现节点。
const PALYER_VISUAL_SCENE := preload("res://Prefab/Role/PlayerVisual.tscn")
const HP_BAR_SCENE := preload("res://Prefab/Role/ProgressBar.tscn")
const MONSTER_VISUAL_SCENE := preload("res://Prefab/Role/MonsterVisual.tscn")
const EXP_VISUAL_SCENE := preload("res://Prefab/Role/ExpVisual.tscn")

const Role = preload("res://Scirpt/game/view/Role.gd")
const PlayerRole = preload("res://Scirpt/game/view/PlayerRole.gd")
const MonsterRole = preload("res://Scirpt/game/view/MonsterRole.gd")

static func create_entity_view(entity_state: EntityState):
	if entity_state.entity_type == EntityState.EntityType.PLAYER:
		return create_role_view(entity_state)

	elif entity_state.entity_type == EntityState.EntityType.ENEMY:
		return create_enemy_view(entity_state)

	elif entity_state.entity_type == EntityState.EntityType.EXP:
		return create_exp_view(entity_state)

static func create_role_view(entity_state: EntityState):
	var view = PlayerRole.new()
	var view_visual = PALYER_VISUAL_SCENE.instantiate()
	view_visual.entity_id = entity_state.entity_id
	view.add_child(view_visual)
	var motion_presenter = MotionPresenter.new(view)
	var animation_presenter = AnimationPresenter.new(view)
	var nameplate_presenter = NameplatePresenter.new(view)
	view.add_presenter(MotionPresenter.presenter_name, motion_presenter)
	view.add_presenter(AnimationPresenter.presenter_name, animation_presenter)
	view.add_presenter(NameplatePresenter.presenter_name, nameplate_presenter)
	view.entity_visual = view_visual

	var entity_hp_bar = HP_BAR_SCENE.instantiate()
	view.add_child(entity_hp_bar)
	var hp_bar_presenter = HpBarPresenter.new(view)
	hp_bar_presenter.set_hp_bar(entity_hp_bar)
	view.add_presenter(HpBarPresenter.presenter_name, hp_bar_presenter)
	
	var combat_presenter = CombatPresenter.new(view)
	view.add_presenter(CombatPresenter.presenter_name, combat_presenter)
	view.add_presenter(ProgressionPresenter.presenter_name, ProgressionPresenter.new(view))

	return view

static func create_enemy_view(entity_state: EntityState):
	# 依据权威模板键选择怪物图集，木桩等无图集对象仍使用通用外观。
	var view = MonsterRole.new()
	var visual_config: Dictionary = ConfigLoader.get_entity_visual_config(entity_state.entity_config_key)
	var view_visual: PlayerVisual
	if not visual_config.is_empty():
		var monster := MONSTER_VISUAL_SCENE.instantiate() as MonsterVisual
		if not monster.configure(entity_state.entity_config_key):
			monster.free()
			view.free()
			return null
		view_visual = monster
	else:
		view_visual = PALYER_VISUAL_SCENE.instantiate() as PlayerVisual

	view_visual.entity_id = entity_state.entity_id
	view.add_child(view_visual)

	var entity_hp_bar = HP_BAR_SCENE.instantiate()
	view.add_child(entity_hp_bar)
	
	var motion_presenter = MotionPresenter.new(view)
	var animation_presenter = AnimationPresenter.new(view)
	var nameplate_presenter = NameplatePresenter.new(view)
	var hp_bar_presenter = HpBarPresenter.new(view)
	hp_bar_presenter.set_hp_bar(entity_hp_bar as MyProgressBar)
	if view_visual is MonsterVisual:
		(view_visual as MonsterVisual).layout_nameplate(entity_hp_bar as MyProgressBar)
	view.add_presenter(MotionPresenter.presenter_name, motion_presenter)
	view.add_presenter(AnimationPresenter.presenter_name, animation_presenter)
	view.add_presenter(NameplatePresenter.presenter_name, nameplate_presenter)
	view.add_presenter(HpBarPresenter.presenter_name, hp_bar_presenter)

	view.entity_visual = view_visual
	var combat_presenter = CombatPresenter.new(view)
	view.add_presenter(CombatPresenter.presenter_name, combat_presenter)
	view.add_presenter(EntityMovePathPresenter.presenter_name, EntityMovePathPresenter.new(view))

	return view

static func create_exp_view(entity_state: EntityState):
	# 经验球只需要图片和移动，不装配角色动画、血条或成长表现。
	var view = EntityView.new()
	var view_visual := EXP_VISUAL_SCENE.instantiate()
	view.add_presenter(MotionPresenter.presenter_name, MotionPresenter.new(view))
	view.add_child(view_visual)
	return view
