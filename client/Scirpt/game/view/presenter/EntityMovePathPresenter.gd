extends EntityViewPresenter
class_name EntityMovePathPresenter
## 管理怪物寻路调试状态，并驱动由关卡 Debug 节点托管的 Painter。

static var presenter_name := &"EntityMovePathPresenter"

var _move_path_state: EntityMovePathState = null
var _painter: EntityPathPainter = null
var _path_visible: bool = false

func process(_delta: float) -> void:
	if not _path_visible or _painter == null:
		return
	_painter.set_start_position(_entity_view.position)

func set_painter(painter: EntityPathPainter) -> void:
	_painter = painter
	_painter.visible = _path_visible
	_refresh_painter()

func set_path_visible(path_visible: bool) -> void:
	_path_visible = path_visible
	if _painter == null:
		return
	_painter.visible = path_visible
	if path_visible:
		_refresh_painter()

func apply_move_path_changed(state: EntityMovePathState) -> void:
	_move_path_state = state
	_refresh_painter()

func _refresh_painter() -> void:
	if _painter == null or _move_path_state == null:
		return
	_painter.set_path(_move_path_state.path, _move_path_state.path_index)
	_painter.set_start_position(_entity_view.position)
