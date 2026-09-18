extends Control

@onready var hp_bar: TextureProgressBar = $PlayerStatus/HpBar
@onready var exp_bar: TextureProgressBar = $PlayerStatus/ExpBar

# 升级所需的总经验值
var upgrade_exp: Dictionary[int, float] = {}

func _ready() -> void:
	SignalMgr.Get().snl_entities_prog_changed.connect(hdl_entities_prog_changed)

	var total_exp := 0.0
	var level = 1
	upgrade_exp[0] = 0.0
	for xp in ConfigLoader.get_reward_config().progression.next_level_xp:
		total_exp += xp
		upgrade_exp[level] = total_exp	
		level += 1

	var entity = GameBootstrap.game_store.get_entity(GameBootstrap.game_store.self_entity_id)
	hdl_entities_prog_changed([entity])

func hdl_entities_prog_changed(change_states: Array[EntityState]):
	for entity_state in change_states:
		if entity_state.entity_id == GameBootstrap.game_store.self_entity_id:
			var entity = GameBootstrap.game_store.get_entity(entity_state.entity_id)
			var max_health = entity.combat_entity_state.max_hp
			set_hp(entity.combat_entity_state.hp, max_health)

			var level = entity.progression_state.level
			if level in upgrade_exp:
				var cur_exp = entity.progression_state.total_exp - upgrade_exp[level - 1]
				set_exp(cur_exp, upgrade_exp[level])
			else:
				set_exp(100, 100)

func set_hp(health: int, max_health: int):
	hp_bar.value = (health * 1.0) / max_health * 100.0

func set_exp(_exp: float, max_exp: float):
	exp_bar.value = _exp / max_exp * 100.0
