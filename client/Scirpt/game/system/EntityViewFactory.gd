extends Object
class_name EntityViewFactory
## 根据权威 EntityState 创建对应的表现节点。

const Role = preload("res://Scirpt/game/view/Role.gd")

static func create_entity_view(entity_state: EntityState):
	var view = Role.new()
	view.setup(entity_state)
	return view
