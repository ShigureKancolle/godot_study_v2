extends Node2D

func _ready() -> void:
	$Bg/LoginButton.pressed.connect(_on_click_login)

func _on_click_login():
	var acc = $Bg/AccountInput.get_text()
	var name = $Bg/NameInput.get_text()
	WebSocketMgr.Get().wsp.send_text("我来了")
