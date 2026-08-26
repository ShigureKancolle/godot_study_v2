extends EntityView
class_name Role


func _ready():
	pass

func __setup(state: EntityState):
	if state.is_local_player:
		self.local_player_controller = LOCAL_PLAYER_CONTROLLER_SCRIPT.new()
		self.add_child(self.local_player_controller)
		self.local_player_controller.setup(self.entity_id)

	
