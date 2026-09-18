extends EntityViewPresenter
class_name NameplatePresenter

static var presenter_name := &"NameplatePresenter"

var _role: Role

func _init(role: Role):
	super(role)
	_role = role

func set_view_name(player_name: String, is_local_player: bool = false):
	if is_local_player:
		player_name += "(你)"
	_role.entity_visual.set_player_name(player_name)
