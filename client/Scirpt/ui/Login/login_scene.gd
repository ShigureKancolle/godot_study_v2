extends Node2D

func _ready() -> void:
	$Bg/LoginButton.pressed.connect(_on_click_login)
	SignalMgr.Get().snl_on_login_accepted.connect(hdl_on_login_accepted)

func _on_click_login():
	var acc: String = $Bg/AccountInput.get_text()
	var name: String = $Bg/NameInput.get_text()
	if acc.strip_edges().is_empty() or name.strip_edges().is_empty():
		push_error("账号和名字不能为空")
	# WebSocketMgr.Get().send_login(acc, name)
	WebSocketMgr.Get().send("login_request", {
		"account": acc,
		"player_name": name,
	})
	

func hdl_on_login_accepted(acc: String, name: String):
	ClientSession.Get().on_login_accepted(acc, name)
	
	# 进入主界面
	get_tree().change_scene_to_file.call_deferred("res://prefab/main/MainScene.tscn")
