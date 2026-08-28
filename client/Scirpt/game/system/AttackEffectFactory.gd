extends Object
class_name AttackEffectFactory

const ATTACK_EFFECT_NAME_FORMAT := "res://Prefab/Effect/AttackEffect_%d.tscn"


static func create_attack_effect(attack_id: int) -> Node2D:
	var scene_path = ATTACK_EFFECT_NAME_FORMAT % attack_id
	
	if not ResourceLoader.exists(scene_path):
		push_error("攻击特效文件不存在，请检查ID: ", attack_id, " 路径: ", scene_path)
		return null

	var scene = load(scene_path)
	if not scene:
		push_error("攻击特效文件加载失败，请检查ID: ", attack_id, " 路径: ", scene_path)
		return null

	return scene.instantiate()
