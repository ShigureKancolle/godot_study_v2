extends RefCounted
class_name NameplatePresenter

var entity_view: EntityView = null

func _init(view: EntityView):
	entity_view = view

func set_name(player_name: String, is_local_player: bool = false):
	if is_local_player:
        player_name += "(你)"
    entity_view.entity_visual.set_player_name(player_name)
