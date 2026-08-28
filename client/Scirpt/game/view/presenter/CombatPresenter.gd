extends EntityViewPresenter
class_name CombatPresenter

static var presenter_name := &"CombatPresenter"

func setup(combat_state: CombatEntityState):
	apply_atk_facing(combat_state.atk_facing)

func apply_atk_facing(facing: float):
	_entity_view.entity_visual.set_atk_rotate(facing)
