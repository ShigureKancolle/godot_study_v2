extends CanvasLayer

const DEBUG_UI_SCENE := preload("res://Prefab/SpecialUI/TestLevelDebugUI.tscn")
var _debugui: TestLevelDebugUI = null

func _ready() -> void:
	SignalMgr.Get().snl_level_debug.connect(hdl_level_debug)

func hdl_level_debug(data: TestLevelDebugUI.LevelDebugData):
	if _debugui == null:
		_debugui = DEBUG_UI_SCENE.instantiate()
		add_child(_debugui)
	_debugui.update(data)
