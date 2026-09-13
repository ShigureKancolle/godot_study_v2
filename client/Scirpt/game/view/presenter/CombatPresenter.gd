extends EntityViewPresenter
class_name CombatPresenter

static var presenter_name := &"CombatPresenter"

func setup(combat_state: CombatEntityState):
	apply_atk_facing(combat_state.atk_facing)

func apply_atk_facing(facing: float):
	_entity_view.entity_visual.set_atk_rotate(facing)

func apply_attack_start(attack_id: int, atk_facing: float):
	# 根据id创建攻击动画 然后挂到entity_view.entity_visual上
	var attack: ConfigLoader.AttackConfig = ConfigLoader.get_attack_config(attack_id)
	if attack == null:
		return
	var animation := _entity_view.get_presenter(AnimationPresenter.presenter_name) as AnimationPresenter
	if animation.is_dead():
		return
	animation.play_attack(atk_facing, attack)
	var atk_effect = AttackEffectFactory.create_attack_effect(attack_id, _entity_view.entity_visual is MonsterVisual)
	if not atk_effect:
		return

	_entity_view.entity_visual.play_atk_effect(atk_effect)
	atk_effect.rotation = -atk_facing

func apply_damage_received(damage: int):
	if damage <= 0:
		return
	var animation := _entity_view.get_presenter(AnimationPresenter.presenter_name) as AnimationPresenter
	animation.play_hurt()
