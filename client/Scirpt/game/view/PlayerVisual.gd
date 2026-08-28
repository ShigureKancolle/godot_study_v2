extends Node2D
class_name PlayerVisual

@onready var _body: AnimatedSprite2D = $Body
@onready var name_label: Label = $NameLabel
@onready var _atk_rotate_arrow: Node2D = $FacingArrow
@onready var _atk_effect: Node2D = $AtkEffect

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

func set_atk_rotate(facing: float):
	# facing是-pi到pi的 要转换到 0到2pi
	var angle = fposmod(facing, (2 * PI))
	
	_atk_rotate_arrow.rotation = -facing

func play_atk_effect(atk_effect: Node2D):
	_atk_effect.add_child(atk_effect)
	# 播完自动消除
	atk_effect.play("Attack")
	atk_effect.animation_finished.connect(_on_animation_finished)

func _on_animation_finished():
	_atk_effect.queue_free()
