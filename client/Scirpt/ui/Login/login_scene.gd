extends Node2D

func _ready() -> void:
	$Bg/LoginButton.pressed.connect(_on_click_login)

func _on_click_login():
	var acc: String = $Bg/AccountInput.get_text()
	var name: String = $Bg/NameInput.get_text()
	if acc.strip_edges().is_empty() or name.strip_edges().is_empty():
		push_error("账号和名字不能为空")
	var result := WebSocketMgr.Get().send_login(acc, name)
	if result != OK:
		$Bg/NameInput.set_text("登录出错")
	else:
		$Bg/NameInput.set_text("登录成功")
