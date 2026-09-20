extends Node2D

@onready var restart: TextureButton = $Panel/Restart
@onready var back: TextureButton = $Panel/Back


func _ready() -> void:
	restart.connect("pressed", on_btn_restart)
	back.connect("pressed", on_btn_back)
	
	
func on_btn_restart():
	WebSocketMgr.Get().send("restart_requset", {
		"entity_id": GameBootstrap.game_store.self_entity_id,
	})
	hide()

func on_btn_back() -> void:
	pass
