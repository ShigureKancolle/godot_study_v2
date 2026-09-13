extends EntityViewPresenter
class_name AnimationPresenter

static var presenter_name := &"AnimationPresenter"


var _facing_dir: String = "Down"
var _current_state: String = "idle"
var _locomotion_state: String = "idle"
var _locomotion_facing: String = "Down"
var _action_remaining: float = 0.0

func is_dead() -> bool:
	return _current_state == "die"

func process(delta: float) -> void:
	if _action_remaining <= 0.0 or is_dead():
		return
	_action_remaining = maxf(0.0, _action_remaining - delta)
	if _action_remaining <= 0.0:
		_current_state = _locomotion_state
		_facing_dir = _locomotion_facing
		_play_current()

func play_attack(facing: float, attack: ConfigLoader.AttackConfig) -> void:
	if is_dead():
		return
	var direction: String = _move_dir_to_facing(Vector2(cos(facing), -sin(facing)))
	var full_name: String = direction + "_Attack"
	if not _entity_view.entity_visual.has_animation(full_name):
		return
	_current_state = "attack"
	_facing_dir = direction
	_action_remaining = float(attack.get_attack_time()) / 1000.0
	_entity_view.entity_visual.play_attack_anim(full_name, attack)

func play_hurt() -> void:
	if is_dead():
		return
	var visual: PlayerVisual = _entity_view.entity_visual
	if visual is MonsterVisual:
		visual.flash_hurt()
	# 受击只叠加颜色反馈，不中断仍在执行的攻击预警和挥击时序。
	if _current_state == "attack":
		return
	if not visual.has_animation(_facing_dir + "_Hurt"):
		return
	_current_state = "hurt"
	_action_remaining = 0.2
	_play_current()


func update_facing(dir: Vector2):
	# 死亡后固定倒地方向，避免残余位置插值切换并重播另一方向的死亡动画。
	if _current_state == "die":
		return
	# print("[AnimationPresenter]  update_facing: %f %f" % [dir.x, dir.y])
	if dir.is_equal_approx(Vector2.ZERO):
		return

	_locomotion_facing = _move_dir_to_facing(dir)
	if _action_remaining > 0.0:
		return
	_facing_dir = _locomotion_facing
	_play_current()

func _move_dir_to_facing(dir: Vector2) -> String:
	# 水平方向略微优先
	var horizontal_strength := absf(dir.x)
	var vertical_strength := absf(dir.y)
	var facing_dir := ""
	if horizontal_strength * 1.1 > vertical_strength:
		if dir.x > 0:
			facing_dir = "Right"
		else:
			facing_dir = "Left"
	else:
		if dir.y < 0:
			facing_dir = "Up"
		else:
			facing_dir = "Down"

	# print("[AnimationPresenter]  dir: " + facing_dir)
	return facing_dir

	

func play_anim(anim_name: String = "idle") -> void:
	# 死亡动画保持到视图移除，后续移动状态和重复死亡通知不能覆盖它。
	if _current_state == "die":
		return
	if anim_name in ["idle", "run"]:
		_locomotion_state = anim_name
		if _action_remaining > 0.0:
			return
	if anim_name == "die":
		_action_remaining = 0.0
	# 缓存当前状态名,facing 变化时要用它拼新方向动画
	_current_state = anim_name
	_play_current()

func _play_current() -> void:
	var full_name: String = _facing_dir + "_" + _current_state.capitalize()
	# 防御:SpriteFrames 里没配的动画名会告警
	if _entity_view.entity_visual.has_animation(full_name):
		# 避免重复播放当前动画(AnimatedSprite2D.play 同名动画会从头开始,这里只想继续)
		_entity_view.entity_visual.play_anim(full_name, false)
	else:
		push_warning("PlayerVisual: 动画不存在: " + full_name)
