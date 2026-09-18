extends Role
class_name MonsterRole
## 怪物专属表现入口，寻路调试表现交给对应 Presenter 处理。

func setup(state: EntityState):
	super.setup(state)
	if state.entity_move_path != null:
		apply_move_path_changed(state.entity_move_path)

func set_path_painter(painter: EntityPathPainter) -> void:
	var presenter := get_presenter(EntityMovePathPresenter.presenter_name) as EntityMovePathPresenter
	presenter.set_painter(painter)

func set_move_path_visible(path_visible: bool) -> void:
	var presenter := get_presenter(EntityMovePathPresenter.presenter_name) as EntityMovePathPresenter
	presenter.set_path_visible(path_visible)

func apply_move_path_changed(state: EntityMovePathState) -> void:
	var presenter := get_presenter(EntityMovePathPresenter.presenter_name) as EntityMovePathPresenter
	presenter.apply_move_path_changed(state)
