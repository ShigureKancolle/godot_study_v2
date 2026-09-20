extends Node2D

@onready var btn_restart: Button = %BtnRestart
@onready var btn_continue: Button = %BtnContinue
@onready var btn_main_menu: Button = %BtnMainMenu


func _ready() -> void:
	btn_continue.connect("pressed", on_btn_continue)
	btn_restart.connect("pressed", on_btn_restart)
	
func on_btn_continue():
	hide()

func _on_visibility_changed() -> void:
	WebSocketMgr.Get().send("pause_game_world", {
		"pause": is_visible()
	})
	SignalMgr.Get().snl_game_pause.emit(is_visible())

func on_btn_restart():
	WebSocketMgr.Get().send("restart_requset", {
		"entity_id": GameBootstrap.game_store.self_entity_id,
	})
	hide()
