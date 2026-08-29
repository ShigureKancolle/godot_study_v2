extends Node2D
class_name PlayerVisual

@onready var _body: AnimatedSprite2D = $Body
@onready var name_label: Label = $NameLabel
@onready var _atk_rotate_arrow: Node2D = $FacingArrow
@onready var _atk_effect_parent: Node2D = $AtkEffect

var _atk_effects: Dictionary[String, Node2D] = {}
var _next_atk_effect_id: int = 0

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
	_next_atk_effect_id += 1
	var atk_effect_key = "atk_effect%d" % _next_atk_effect_id
	_atk_effects[atk_effect_key] = atk_effect
	_atk_effect_parent.add_child(atk_effect)

	var animated_sprite := atk_effect.get_node(
		"Scale/AnimatedSprite2D"
	) as AnimatedSprite2D
	# 播完自动消除
	animated_sprite.animation_finished.connect(
		_on_animation_finished.bind(atk_effect_key),
		CONNECT_ONE_SHOT
	)
	animated_sprite.play("Attack")

func _on_animation_finished(atk_effect_key: String):
	var atk_effect := _atk_effects.get(atk_effect_key) as Node2D
	_atk_effects.erase(atk_effect_key)

	if is_instance_valid(atk_effect):
		atk_effect.queue_free()