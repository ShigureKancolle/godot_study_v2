extends Node2D
class_name PlayerVisual

@onready var _body: AnimatedSprite2D = $Body
@onready var name_label: Label = $NameLabel

func has_animation(anim_name: String) -> bool:
	return _body.sprite_frames.has_animation(anim_name)

func play_anim(anim_name: String = "idle", reset: bool = false) -> void:
	if not has_animation(anim_name):
		return

	if _body.animation != anim_name or reset:
		_body.play(anim_name)

func set_player_name(player_name: String):
	name_label.text = player_name

func replay_cur_anim() -> void:
	if _body == null:
		return
	_body.set_frame(0)
