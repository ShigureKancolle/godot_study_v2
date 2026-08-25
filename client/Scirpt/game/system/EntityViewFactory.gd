extends Object
class_name EntityViewFactory

const Role = preload("res://Scirpt/game/view/Role.gd")

static func create_entity_view(entity_state: EntityState):
	var view = Role.new()
	view.setup(entity_state)
	return view
