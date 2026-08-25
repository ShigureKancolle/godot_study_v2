extends Node2D

@onready var lbl_name: RichTextLabel = $Bg/lblName
@onready var lbl_account: RichTextLabel = $Bg/lblAccount
@onready var e_game_real: Button = $Bg/E_GameReal

var player_name: String = ""
var account := ""

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	lbl_name.text = ClientSession.Get().player_name
	lbl_account.text = ClientSession.Get().account
	e_game_real.pressed.connect(on_click_game_real)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func on_click_game_real():
	WebSocketMgr.Get().send("enter_game_request", {
		"room_id": "0",
		"create_room": false,
		"player_name": ClientSession.Get().player_name
	})
