extends EntityView
class_name Role
## 玩家和怪物共有的动画、名字、血条和战斗表现，由 Factory 保证依赖齐全。

var entity_visual: PlayerVisual = null

func setup(state: EntityState):
	super.setup(state)
	var combat_state := state.combat_entity_state
	assert(combat_state != null, "角色必须携带战斗状态")
	assert(entity_visual != null, "角色必须装配外观节点")
	get_presenter(AnimationPresenter.presenter_name).update_facing(state.facing_dir)
	get_presenter(NameplatePresenter.presenter_name).set_view_name(state.player_name, state.is_local_player)
	get_presenter(HpBarPresenter.presenter_name).update_hp_bar(combat_state.hp, combat_state.max_hp)
	get_presenter(CombatPresenter.presenter_name).setup(combat_state)
	# 中途收到快照时直接呈现死亡，不先播放存活动画。
	if combat_state.dead:
		play_dead_animation()
	else:
		get_presenter(AnimationPresenter.presenter_name).play_anim(state.anim_state if not state.anim_state.is_empty() else "idle")

func apply_movement(state: EntityState) -> void:
	super.apply_movement(state)
	get_presenter(AnimationPresenter.presenter_name).play_anim(state.anim_state)
	get_presenter(AnimationPresenter.presenter_name).update_facing(state.facing_dir)

func apply_attack_start(attack_id: int, atk_facing: float):
	get_presenter(CombatPresenter.presenter_name).apply_attack_start(attack_id, atk_facing)

func apply_aims_changed(state: EntityState):
	apply_atk_rotate(state.combat_entity_state.atk_facing)

func apply_atk_rotate(facing: float):
	get_presenter(CombatPresenter.presenter_name).apply_atk_facing(facing)

func apply_animation(state: EntityState) -> void:
	get_presenter(AnimationPresenter.presenter_name).play_anim(state.anim_state)

func apply_combat(state: CombatEntityState) -> void:
	apply_atk_rotate(state.atk_facing)

func apply_hp_changed(state: EntityState) -> void:
	get_presenter(HpBarPresenter.presenter_name).update_hp_bar(state.combat_entity_state.hp, state.combat_entity_state.max_hp)

func apply_damage_received(damage: int):
	get_presenter(CombatPresenter.presenter_name).apply_damage_received(damage)

func play_dead_animation():
	get_presenter(AnimationPresenter.presenter_name).play_anim("die")

	
