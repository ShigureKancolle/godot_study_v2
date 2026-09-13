extends PlayerVisual
class_name MonsterVisual
## 怪物共用表现节点，资源由服务端传来的模板键选择。

var entity_config_key: String = ""
var _active_attack: ConfigLoader.AttackConfig = null
var _attack_elapsed_ms: float = 0.0
var _flash_seconds: float = 0.0

func configure(config_key: String) -> bool:
	entity_config_key = config_key
	var visual: Dictionary = ConfigLoader.get_entity_visual_config(config_key)
	var capability: ConfigLoader.EntityCapability = ConfigLoader.get_capability(config_key)
	var frames: SpriteFrames = MonsterAnimationLibrary.build(visual, capability.dead_duration_ms)
	if frames == null:
		return false
	var body := get_node("Body") as AnimatedSprite2D
	body.sprite_frames = frames
	body.animation = &"Down_Idle"
	body.autoplay = "Down_Idle"
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var frame_texture: Texture2D = frames.get_frame_texture(&"Down_Idle", 0)
	body.scale = Vector2.ONE * float(visual.get("render_size_px", 80.0)) / frame_texture.get_width()
	var label := get_node("NameLabel") as Label
	label.text = String(visual.get("display_name", config_key))
	label.position.y = -float(visual.get("render_size_px", 80.0)) * 0.5 - 14.0
	label.add_theme_color_override("font_color", Color("efe6d2"))
	label.add_theme_color_override("font_outline_color", Color("181923"))
	label.add_theme_constant_override("outline_size", 4)
	get_node("FacingArrow").visible = false
	return true

func set_player_name(player_name: String) -> void:
	if player_name.is_empty():
		var visual: Dictionary = ConfigLoader.get_entity_visual_config(entity_config_key)
		super.set_player_name(String(visual.get("display_name", entity_config_key)))
	else:
		super.set_player_name(player_name)

func play_anim(anim_name: String = "idle", reset: bool = false) -> void:
	if not anim_name.ends_with("_Attack"):
		_active_attack = null
	super.play_anim(anim_name, reset)

func play_attack_anim(anim_name: String, attack: ConfigLoader.AttackConfig) -> void:
	if not has_animation(anim_name):
		return
	_active_attack = attack
	_attack_elapsed_ms = 0.0
	_body.animation = StringName(anim_name)
	_body.stop()
	_body.frame = 0

func flash_hurt() -> void:
	_flash_seconds = 0.12

func _process(delta: float) -> void:
	if _flash_seconds > 0.0:
		_flash_seconds = maxf(0.0, _flash_seconds - delta)
		_body.modulate = Color(1.5, 0.65, 0.65) if _flash_seconds > 0.0 else Color.WHITE
	if _active_attack == null:
		return
	_attack_elapsed_ms += delta * 1000.0
	var segment_start: float = 0.0
	# 根据攻击配置来调整动画进度
	for shape: ConfigLoader.AttackShape in _active_attack.shape_list:
		if _attack_elapsed_ms <= shape.duration:
			var windup_middle: float = (segment_start + shape.hit_time) * 0.5
			var recover_start: float = shape.hit_time + (shape.duration - shape.hit_time) * 0.4
			if _attack_elapsed_ms < windup_middle:
				_body.frame = 0
			elif _attack_elapsed_ms < shape.hit_time:
				_body.frame = 1
			elif _attack_elapsed_ms < recover_start:
				_body.frame = 2
			else:
				_body.frame = 3
			return
		segment_start = shape.duration
	_body.frame = 3
