extends Object
class_name AttackEffectFactory

const ATTACK_EFFECT_NAME_FORMAT := "res://Prefab/Effect/AttackEffect_%d.tscn"


static func create_attack_effect(attack_id: int, is_enemy: bool = false) -> Node2D:
	var attack: ConfigLoader.AttackConfig = ConfigLoader.get_attack_config(attack_id)
	if attack == null:
		push_error("攻击配置不存在: %d" % attack_id)
		return null
	var scene_path = ATTACK_EFFECT_NAME_FORMAT % attack_id
	# 怪物统一使用准确的配置预警；无专用美术的攻击也使用同一时间轴表现。
	if is_enemy or not ResourceLoader.exists(scene_path):
		var configured_effect := ConfiguredAttackEffect.new()
		configured_effect.setup(attack, is_enemy)
		return configured_effect
	
	var scene = load(scene_path)
	if not scene:
		push_error("攻击特效文件加载失败，请检查ID: ", attack_id, " 路径: ", scene_path)
		return null

	return scene.instantiate()
