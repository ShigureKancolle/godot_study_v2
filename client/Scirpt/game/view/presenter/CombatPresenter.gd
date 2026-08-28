extends EntityViewPresenter
class_name CombatPresenter

static var presenter_name := &"CombatPresenter"

func setup(combat_state: CombatEntityState):
	apply_atk_facing(combat_state.atk_facing)

func apply_atk_facing(facing: float):
	_entity_view.entity_visual.set_atk_rotate(facing)

func apply_attack_start(attack_id: int, atk_facing: float):
	# 根据id创建攻击动画 然后挂到entity_view.entity_visual上
	var atk_effect = AttackEffectFactory.create_attack_effect(attack_id)
	if not atk_effect:
		return

	_entity_view.entity_visual.play_atk_effect(atk_effect)
	atk_effect.rotation = -atk_facing
