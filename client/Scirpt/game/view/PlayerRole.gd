extends Role
class_name PlayerRole
## 玩家专属成长表现；只有本地玩家装配输入控制器，不在客户端结算经验。

const LOCAL_PLAYER_CONTROLLER_SCRIPT := preload("res://Scirpt/game/controller/LocalPlayerController.gd")

var local_player_controller: LocalPlayerController = null

func setup(state: EntityState):
	super.setup(state)
	assert(state.progression_state != null, "玩家必须携带成长状态")
	apply_prog_changed(state)
	if state.is_local_player:
		local_player_controller = LOCAL_PLAYER_CONTROLLER_SCRIPT.new()
		add_child(local_player_controller)
		local_player_controller.setup(entity_id)

func apply_prog_changed(state: EntityState) -> void:
	get_presenter(ProgressionPresenter.presenter_name).apply_prog_changed(state.progression_state)
