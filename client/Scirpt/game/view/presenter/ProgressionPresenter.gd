extends EntityViewPresenter
class_name ProgressionPresenter

static var presenter_name := &"ProgressionPresenter"

func apply_prog_changed(_prog_state: ProgressionState) -> void:
	# 当前没有角色本体上的成长表现，状态信号不在 Presenter 中重复发送。
	pass
