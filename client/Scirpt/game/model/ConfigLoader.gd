extends RefCounted
class_name ConfigLoader

## 从 res://config 读取与服务端同源的配置，首次访问时读取并缓存，不做配置内容校验。
## 唯一源表位于 json_config，使用 tools/sync_config.py 同步到双端。
## 攻击、实体、奖励、生存使用类型对象；奖励和生存接口返回完整对象副本。
## JSON 角度在加载时转换为弧度，毫秒字段保持毫秒。



# ===========================================================================
# ShapeType 形状类型枚举(字符串值,和服务端 config_loader.ShapeType 对齐)
# ===========================================================================
# 实体碰撞形状和攻击形状共用这套枚举
const ShapeType_SECTOR: String = "sector"
const ShapeType_RECT: String = "rect"
const ShapeType_CIRCLE: String = "circle"
const ShapeType_RING: String = "ring"


# ===========================================================================
# 形状参数 inner class(和服务端 config_loader.py 的 dataclass 对齐)
# ===========================================================================
class ShapeParams:
	"""形状参数基类,实际参数由子类决定"""
	pass


class SectorParams:
	extends ShapeParams
	var radius: float = 35.0    # 扇形半径(像素)
	var angle: float = 2.094    # 扇形角度(弧度,默认 120°)


class CircleParams:
	extends ShapeParams
	var radius: float = 24.0    # 圆形半径(像素)


class RectParams:
	extends ShapeParams
	var width: float = 0.0
	var length: float = 0.0
	var distance: float = 0.0


# ===========================================================================
# 战斗属性 inner class(类型级基础值,EntityInfo 初始化时拷贝一份作为实例运行时状态)
# ===========================================================================
class CombatStats:
	"""
	实体战斗属性(类型级基础值)。

	语义:这里是「该类型的初始/基础战斗属性」,所有同类型实体共享同一份数值。
	运行时强化(玩家成长/敌人每波强化)应该改 EntityInfo 里拷贝出来的实例副本,
	不应该回写到这里(配置是只读的)。

	伤害公式在 StateMirror/game_room 算,不在这层:
		final = attacker.attack_power * atk_shape.damage_percent * 防御系数
	defense 参与防御系数计算。
	"""
	var max_hp: int = 0           # 最大血量
	var attack_power: int = 0     # 攻击力基础值(乘以攻击配置的 damage_percent 得最终伤害)
	var defense: int = 0          # 防御力(参与伤害减免公式)


# ===========================================================================
# 攻击配置 inner class
# ===========================================================================
class AttackShape:
	var shape: String = ShapeType_SECTOR       # 形状类型字符串(和 ShapeType_XXX 值对齐)
	var shape_params: Variant = null           # ShapeParams 子类对象,根据 shape 决定
	var duration: int = 583                    # 攻击持续时间(ms)
	var hit_time: int = 83                     # 判定帧时间(从发起算,ms)
	var damage_multiplier: float = 1.0         # 伤害倍率(和服务端 AttackShape.damage_multiplier 对齐)
	var knockback_distance: float = 0.0
	# 注:原 hit_mask 字段已移除。命中层级改由实体类型的 attack_mask 决定
	# (玩家=2 打敌人层,敌人=1 打玩家层),玩家和敌人可复用同一 atk_id

class AttackConfig:
	var shape_list: Array = []                 # Array[AttackShape]
	var colldown_ms: int = 500

	func get_attack_time() -> int:
		var result: int = 0
		for shape: AttackShape in shape_list:
			result = maxi(result, shape.duration)
		return result
	


# ===========================================================================
# 地形能力 inner class(地图 tile 类型 → 是否可通行等属性)
# ===========================================================================
# ChunkGenerator.get_tile_type_v3 返回 TerrainType 枚举值(int),
# 本配置表把枚举值映射成能力字段,供客户端调试/可视化寻路用。
# 服务端也有一份对称的实现(见 server/config/config_loader.py)
# 地形类型 → 名称映射(和 ChunkGenerator.TerrainType 枚举顺序对齐):
#   0=GRASS, 1=SAND, 2=DIRT, 3=BRICK, 4=WATER
const _TERRAIN_ID_TO_NAME: Dictionary = {
	0: "GRASS",
	1: "SAND",
	2: "DIRT",
	3: "BRICK",
	4: "WATER",
}


class TerrainCapability:
	"""
	单个地形类型的能力配置(和服务端 config_loader.TerrainCapability 对称)。

	字段:
		walkable: 是否可通行(AI 寻路用)。true=可通行,false=障碍。
		          ChunkGenerator 当前只生成 GRASS/SAND,都是 true;
		          BRICK 是预留的障碍地形(城墙/墙壁类)。
		move_cost: 通行代价(预留,当前未用)。A* 寻路默认每格代价 1。
	"""
	var walkable: bool = true
	var move_cost: int = 1


# ===========================================================================
# 视野(视锥)配置 inner class(和服务端 config_loader.VisionParams 对称)
# ===========================================================================
# 敌人视锥渲染用:半角 + 半径,按 AI 状态选 normal/chase 两套。
# JSON 里 half_angle_deg 用角度存(人读直观),构造时转弧度(代码计算用),
# 和服务端 config_loader 一致。
class VisionInfo:
	var half_angle: float = 0.0   # 视野半角(弧度,朝向左右各多少)
	var radius: float = 0.0       # 视野半径(像素)


# ===========================================================================
# 实体能力+碰撞形状 inner class
# ===========================================================================
class EntityCapability:
	# 能力字段
	var can_move: bool = false
	var can_attack: bool = false
	var can_be_hurt: bool = false
	var can_disconnect: bool = false
	var can_die: bool = false                  # 能否进入死亡流程(hp<=0 时判定)。player=false 暂不实现,敌人=true
	# 碰撞形状字段
	var body_shape: String = ShapeType_CIRCLE
	var body_params: Variant = null            # ShapeParams 子类对象
	var hit_layer: int = 0x00000000            # 被判定层掩码(和服务端 EntityConfig.hit_layer 对齐,默认 1=玩家)
	var attack_mask: int = 0x00000000           # 攻击判定掩码(和服务端 EntityConfig.attack_mask 对齐。玩家=2 打敌人层,敌人=1 打玩家层,木桩=0)
	# 移动速度(像素/秒,类型级基础值。can_move=false 时为 0。
	# LocalPlayerController 用 player_speed * delta 算每帧步长;
	# 运行时若有减速/加速 buff 应改实例副本,不回写配置)
	var speed: float = 0.0
	# 死亡动画时长(毫秒)。can_die=false 时为 0。
	# 和服务端 config_loader.EntityCapability.dead_duration_ms 对齐。
	var dead_duration_ms: int = 0
	# 基础战斗属性(类型级,EntityInfo 初始化时从这里拷贝一份作为实例运行时状态)
	var combat_stats: CombatStats = null       # _init 里保证 new 出来,避免 null 风险
	var body_color: String = "#ffffff"         # 角色身体颜色(HEX 字符串,纯客户端显示属性,服务端不传也不读)
	func _init():
		combat_stats = CombatStats.new()

# ===========================================================================
# 导航地图 格子地图
# ===========================================================================
class NavigationMap:
	var terrain_ids: Array[int] = []
	var map_id: String = ""
	var tile_size_px: Vector2i = Vector2i(16, 16)
	# block是2*2的cell 这个字段表示block的长宽个数
	var block_bounds_start: Vector2i = Vector2i(-34, -22)
	var block_bounds_end: Vector2i = Vector2i(34, 22)
	var block_size: Vector2i = Vector2i(2, 2)


# ===========================================================================
# 奖励与生存配置对象，字段与服务端 balance_config.py 对齐
# ===========================================================================
class BalanceConfigObject:
	extends RefCounted
	## 各类型显式复制存储字段；计算属性不参与复制。
	func copy() -> BalanceConfigObject:
		push_error("配置类型未实现对象复制")
		return null

	static func _copy_value(value: Variant) -> Variant:
		if value is BalanceConfigObject:
			return value.copy()
		if value is Array:
			var result: Array = value.duplicate()
			for index in range(result.size()):
				result[index] = _copy_value(result[index])
			return result
		if value is Dictionary:
			var result: Dictionary = value.duplicate()
			for key in result:
				result[key] = _copy_value(result[key])
			return result
		return value

## 单项强化操作。
class RewardEffect:
	extends BalanceConfigObject
	var stat: String = ""
	var operation: String = ""
	var value: float = 0.0

	func copy() -> BalanceConfigObject:
		var result := RewardEffect.new()
		result.stat = _copy_value(stat)
		result.operation = _copy_value(operation)
		result.value = _copy_value(value)
		return result


## 可选择的一种奖励。
class RewardDefinition:
	extends BalanceConfigObject
	var reward_id: String = ""
	var name: String = ""
	var description: String = ""
	var weight: float = 0.0
	var max_stacks: Variant = null
	var effects: Array[RewardEffect] = []
	# max_stacks 的 null 表示一次性奖励，不保存叠层。

	func copy() -> BalanceConfigObject:
		var result := RewardDefinition.new()
		result.reward_id = _copy_value(reward_id)
		result.name = _copy_value(name)
		result.description = _copy_value(description)
		result.weight = _copy_value(weight)
		result.max_stacks = _copy_value(max_stacks)
		result.effects = _copy_value(effects)
		return result


## 局内等级、经验阈值与拾取规则。
class RewardProgression:
	extends BalanceConfigObject
	var initial_level: int = 0
	var max_level: int = 0
	var next_level_xp: Array[int] = []
	var base_pickup_radius_px: float = 0.0
	var collect_dropped_xp_on_stage_end: bool = false
	var overflow_policy: String = ""

	func copy() -> BalanceConfigObject:
		var result := RewardProgression.new()
		result.initial_level = _copy_value(initial_level)
		result.max_level = _copy_value(max_level)
		result.next_level_xp = _copy_value(next_level_xp)
		result.base_pickup_radius_px = _copy_value(base_pickup_radius_px)
		result.collect_dropped_xp_on_stage_end = _copy_value(collect_dropped_xp_on_stage_end)
		result.overflow_policy = _copy_value(overflow_policy)
		return result


## 候选奖励的抽取、暂停与超时规则。
class RewardChoice:
	extends BalanceConfigObject
	var option_count: int = 0
	var timeout_ms: int = 0
	var pause_single_player: bool = false
	var pause_multiplayer: bool = false
	var pool: Array[String] = []
	var guaranteed_any_of: Array[String] = []
	var auto_choice_priority: Array[String] = []
	var fallback_reward_id: String = ""
	var fallback_max_per_choice: int = 0
	var allow_fewer_options: bool = false
	var empty_choice_policy: String = ""

	func copy() -> BalanceConfigObject:
		var result := RewardChoice.new()
		result.option_count = _copy_value(option_count)
		result.timeout_ms = _copy_value(timeout_ms)
		result.pause_single_player = _copy_value(pause_single_player)
		result.pause_multiplayer = _copy_value(pause_multiplayer)
		result.pool = _copy_value(pool)
		result.guaranteed_any_of = _copy_value(guaranteed_any_of)
		result.auto_choice_priority = _copy_value(auto_choice_priority)
		result.fallback_reward_id = _copy_value(fallback_reward_id)
		result.fallback_max_per_choice = _copy_value(fallback_max_per_choice)
		result.allow_fewer_options = _copy_value(allow_fewer_options)
		result.empty_choice_policy = _copy_value(empty_choice_policy)
		return result


## 奖励操作的说明契约，不执行属性计算。
class RewardEffectRules:
	extends BalanceConfigObject
	var add_base_ratio: String = ""
	var add_flat: String = ""
	var heal_flat: String = ""
	var heal_max_hp_ratio: String = ""
	var attack_range: String = ""

	func copy() -> BalanceConfigObject:
		var result := RewardEffectRules.new()
		result.add_base_ratio = _copy_value(add_base_ratio)
		result.add_flat = _copy_value(add_flat)
		result.heal_flat = _copy_value(heal_flat)
		result.heal_max_hp_ratio = _copy_value(heal_max_hp_ratio)
		result.attack_range = _copy_value(attack_range)
		return result


## 一种怪物的击杀奖励与发放方式。
class KillReward:
	extends BalanceConfigObject
	var xp: int = 0
	var delivery: String = ""
	var bundle_id: String = ""

	func copy() -> BalanceConfigObject:
		var result := KillReward.new()
		result.xp = _copy_value(xp)
		result.delivery = _copy_value(delivery)
		result.bundle_id = _copy_value(bundle_id)
		return result


## 固定礼包的发放上限和效果。
class RewardBundle:
	extends BalanceConfigObject
	var max_grants_per_run: int = 0
	var effects: Array[RewardEffect] = []

	func copy() -> BalanceConfigObject:
		var result := RewardBundle.new()
		result.max_grants_per_run = _copy_value(max_grants_per_run)
		result.effects = _copy_value(effects)
		return result


## 结算积分与局内成长清理规则。
class RewardSettlement:
	extends BalanceConfigObject
	var completed_normal_stage_score: int = 0
	var elite_kill_score: int = 0
	var boss_kill_score: int = 0
	var reset_progression_on_restart: bool = false

	func copy() -> BalanceConfigObject:
		var result := RewardSettlement.new()
		result.completed_normal_stage_score = _copy_value(completed_normal_stage_score)
		result.elite_kill_score = _copy_value(elite_kill_score)
		result.boss_kill_score = _copy_value(boss_kill_score)
		result.reset_progression_on_restart = _copy_value(reset_progression_on_restart)
		return result


## 完整奖励对象；字典仅用于按编号索引类型对象。
class RewardConfig:
	extends BalanceConfigObject
	var schema_version: int = 0
	var progression: RewardProgression = null
	var choice: RewardChoice = null
	var effect_rules: RewardEffectRules = null
	var rewards: Dictionary[String, RewardDefinition] = {}
	var kill_rewards: Dictionary[String, KillReward] = {}
	var bundles: Dictionary[String, RewardBundle] = {}
	var settlement: RewardSettlement = null

	func copy() -> BalanceConfigObject:
		var result := RewardConfig.new()
		result.schema_version = _copy_value(schema_version)
		result.progression = _copy_value(progression)
		result.choice = _copy_value(choice)
		result.effect_rules = _copy_value(effect_rules)
		result.rewards = _copy_value(rewards)
		result.kill_rewards = _copy_value(kill_rewards)
		result.bundles = _copy_value(bundles)
		result.settlement = _copy_value(settlement)
		return result


## 开局、阶段推进和胜负判定规则。
class SurvivalRun:
	extends BalanceConfigObject
	var start_on_first_player: bool = false
	var min_players: int = 0
	var max_players: int = 0
	var late_join_policy: String = ""
	var advance_stage_policy: String = ""
	var victory_condition: String = ""
	var timeout_result: String = ""
	var all_players_dead_result: String = ""
	var same_tick_priority: Array[String] = []
	var reference_player_attack_id: int = 0

	func copy() -> BalanceConfigObject:
		var result := SurvivalRun.new()
		result.start_on_first_player = _copy_value(start_on_first_player)
		result.min_players = _copy_value(min_players)
		result.max_players = _copy_value(max_players)
		result.late_join_policy = _copy_value(late_join_policy)
		result.advance_stage_policy = _copy_value(advance_stage_policy)
		result.victory_condition = _copy_value(victory_condition)
		result.timeout_result = _copy_value(timeout_result)
		result.all_players_dead_result = _copy_value(all_players_dead_result)
		result.same_tick_priority = _copy_value(same_tick_priority)
		result.reference_player_attack_id = _copy_value(reference_player_attack_id)
		return result


## 按开局人数计算的强度、刷怪和经验规则。
class SurvivalMultiplayer:
	extends BalanceConfigObject
	var lock_player_count_at_start: bool = false
	var normal_budget_multiplier_per_player: float = 0.0
	var normal_alive_cap_multiplier_per_player: float = 0.0
	var normal_spawn_rate_multiplier_per_player: float = 0.0
	var special_hp_extra_per_additional_player: float = 0.0
	var normal_xp_distribution: String = ""
	var stage_xp_distribution: String = ""

	func copy() -> BalanceConfigObject:
		var result := SurvivalMultiplayer.new()
		result.lock_player_count_at_start = _copy_value(lock_player_count_at_start)
		result.normal_budget_multiplier_per_player = _copy_value(normal_budget_multiplier_per_player)
		result.normal_alive_cap_multiplier_per_player = _copy_value(normal_alive_cap_multiplier_per_player)
		result.normal_spawn_rate_multiplier_per_player = _copy_value(normal_spawn_rate_multiplier_per_player)
		result.special_hp_extra_per_additional_player = _copy_value(special_hp_extra_per_additional_player)
		result.normal_xp_distribution = _copy_value(normal_xp_distribution)
		result.stage_xp_distribution = _copy_value(stage_xp_distribution)
		return result


## 精英和首领的独立存活上限。
class SpecialAliveCaps:
	extends BalanceConfigObject
	var elite: int = 0
	var boss: int = 0

	func copy() -> BalanceConfigObject:
		var result := SpecialAliveCaps.new()
		result.elite = _copy_value(elite)
		result.boss = _copy_value(boss)
		return result


## 普通阶段前、中、后三段的预算节奏。
class NormalStagePulse:
	extends BalanceConfigObject
	var opening_seconds: float = 0.0
	var closing_seconds: float = 0.0
	var opening_rate_multiplier: float = 0.0
	var middle_rate_multiplier: float = 0.0
	var closing_rate_multiplier: float = 0.0

	func copy() -> BalanceConfigObject:
		var result := NormalStagePulse.new()
		result.opening_seconds = _copy_value(opening_seconds)
		result.closing_seconds = _copy_value(closing_seconds)
		result.opening_rate_multiplier = _copy_value(opening_rate_multiplier)
		result.middle_rate_multiplier = _copy_value(middle_rate_multiplier)
		result.closing_rate_multiplier = _copy_value(closing_rate_multiplier)
		return result


## 出生点到所选玩家中心的距离、导航和尝试次数配置；距离使用世界单位。
class SpawnPosition:
	extends BalanceConfigObject
	var require_outside_all_alive_views: bool = false
	var spawn_distance_min_px: float = 0.0
	var spawn_distance_max_px: float = 0.0
	var minimum_approach_seconds: float = 0.0
	var require_walkable: bool = false
	var require_reachable_player: bool = false
	var max_position_attempts: int = 0
	var failure_policy: String = ""

	func copy() -> BalanceConfigObject:
		var result := SpawnPosition.new()
		result.require_outside_all_alive_views = _copy_value(require_outside_all_alive_views)
		result.spawn_distance_min_px = _copy_value(spawn_distance_min_px)
		result.spawn_distance_max_px = _copy_value(spawn_distance_max_px)
		result.minimum_approach_seconds = _copy_value(minimum_approach_seconds)
		result.require_walkable = _copy_value(require_walkable)
		result.require_reachable_player = _copy_value(require_reachable_player)
		result.max_position_attempts = _copy_value(max_position_attempts)
		result.failure_policy = _copy_value(failure_policy)
		return result


## 远距离回收的角色范围和实例保留规则。
class SpawnRecycle:
	extends BalanceConfigObject
	var roles: Array[String] = []
	var outside_view_margin_px: float = 0.0
	var preserve_instance_state: bool = false
	var grant_rewards: bool = false

	func copy() -> BalanceConfigObject:
		var result := SpawnRecycle.new()
		result.roles = _copy_value(roles)
		result.outside_view_margin_px = _copy_value(outside_view_margin_px)
		result.preserve_instance_state = _copy_value(preserve_instance_state)
		result.grant_rewards = _copy_value(grant_rewards)
		return result


## 预算、生成频率、位置与回收配置。
class SurvivalSpawn:
	extends BalanceConfigObject
	var spawn_check_interval_seconds: float = 0.0
	var max_normal_spawns_per_second: int = 0
	var budget_carry_seconds: float = 0.0
	var budget_carry_min_enemy_count: int = 0
	var clear_budget_on_stage_change: bool = false
	var special_alive_caps: SpecialAliveCaps = null
	var normal_stage_pulse: NormalStagePulse = null
	var position: SpawnPosition = null
	var recycle: SpawnRecycle = null

	func copy() -> BalanceConfigObject:
		var result := SurvivalSpawn.new()
		result.spawn_check_interval_seconds = _copy_value(spawn_check_interval_seconds)
		result.max_normal_spawns_per_second = _copy_value(max_normal_spawns_per_second)
		result.budget_carry_seconds = _copy_value(budget_carry_seconds)
		result.budget_carry_min_enemy_count = _copy_value(budget_carry_min_enemy_count)
		result.clear_budget_on_stage_change = _copy_value(clear_budget_on_stage_change)
		result.special_alive_caps = _copy_value(special_alive_caps)
		result.normal_stage_pulse = _copy_value(normal_stage_pulse)
		result.position = _copy_value(position)
		result.recycle = _copy_value(recycle)
		return result


## 怪物在生存模式中的角色、价格和倍率开关。
class SurvivalEnemy:
	extends BalanceConfigObject
	var role: String = ""
	var spawn_cost: int = 0
	var apply_stage_scaling: bool = false

	func copy() -> BalanceConfigObject:
		var result := SurvivalEnemy.new()
		result.role = _copy_value(role)
		result.spawn_cost = _copy_value(spawn_cost)
		result.apply_stage_scaling = _copy_value(apply_stage_scaling)
		return result


## 按玩法时间独立投放的特殊怪事件。
class TimedSpawn:
	extends BalanceConfigObject
	var event_id: String = ""
	var at_combat_seconds: float = 0.0
	var enemy_type: String = ""
	var cap_reached_policy: String = ""

	func copy() -> BalanceConfigObject:
		var result := TimedSpawn.new()
		result.event_id = _copy_value(event_id)
		result.at_combat_seconds = _copy_value(at_combat_seconds)
		result.enemy_type = _copy_value(enemy_type)
		result.cap_reached_policy = _copy_value(cap_reached_policy)
		return result


## 阶段进入时的首领投放事件。
class EntrySpawn:
	extends BalanceConfigObject
	var event_id: String = ""
	var enemy_type: String = ""
	var position_failure_policy: String = ""

	func copy() -> BalanceConfigObject:
		var result := EntrySpawn.new()
		result.event_id = _copy_value(event_id)
		result.enemy_type = _copy_value(enemy_type)
		result.position_failure_policy = _copy_value(position_failure_policy)
		return result


## 普通怪的预算分配，不代表生成数量占比。
class SpawnPoolEntry:
	extends BalanceConfigObject
	var enemy_type: String = ""
	var budget_share: float = 0.0

	func copy() -> BalanceConfigObject:
		var result := SpawnPoolEntry.new()
		result.enemy_type = _copy_value(enemy_type)
		result.budget_share = _copy_value(budget_share)
		return result


## 一局中的单个阶段。
class SurvivalStage:
	extends BalanceConfigObject
	var stage_id: int = 0
	var name: String = ""
	var duration_seconds: float = 0.0
	var normal_budget_per_minute: float = 0.0
	var normal_alive_cap: int = 0
	var use_normal_stage_pulse: bool = false
	var hp_multiplier: float = 0.0
	var attack_multiplier: float = 0.0
	var completion_xp: int = 0
	var pool: Array[SpawnPoolEntry] = []
	var clear_roles_on_entry: Array[String] = []
	var grant_rewards_for_entry_clear: bool = false
	var entry_spawn: EntrySpawn = null

	func copy() -> BalanceConfigObject:
		var result := SurvivalStage.new()
		result.stage_id = _copy_value(stage_id)
		result.name = _copy_value(name)
		result.duration_seconds = _copy_value(duration_seconds)
		result.normal_budget_per_minute = _copy_value(normal_budget_per_minute)
		result.normal_alive_cap = _copy_value(normal_alive_cap)
		result.use_normal_stage_pulse = _copy_value(use_normal_stage_pulse)
		result.hp_multiplier = _copy_value(hp_multiplier)
		result.attack_multiplier = _copy_value(attack_multiplier)
		result.completion_xp = _copy_value(completion_xp)
		result.pool = _copy_value(pool)
		result.clear_roles_on_entry = _copy_value(clear_roles_on_entry)
		result.grant_rewards_for_entry_clear = _copy_value(grant_rewards_for_entry_clear)
		result.entry_spawn = _copy_value(entry_spawn)
		return result


## 完整生存对象；阶段和事件按时间顺序保存。
class SurvivalConfig:
	extends BalanceConfigObject
	var schema_version: int = 0
	var balance_version: String = ""
	var run: SurvivalRun = null
	var multiplayer: SurvivalMultiplayer = null
	var spawn: SurvivalSpawn = null
	var enemies: Dictionary[String, SurvivalEnemy] = {}
	var timed_spawns: Array[TimedSpawn] = []
	var stages: Array[SurvivalStage] = []

	var duration_seconds: float:
		get:
			var result: float = 0.0
			for stage: SurvivalStage in stages:
				result += stage.duration_seconds
			return result


# ===========================================================================
# 内部辅助:从 dict 构造对象
# ===========================================================================

	func copy() -> BalanceConfigObject:
		var result := SurvivalConfig.new()
		result.schema_version = _copy_value(schema_version)
		result.balance_version = _copy_value(balance_version)
		result.run = _copy_value(run)
		result.multiplayer = _copy_value(multiplayer)
		result.spawn = _copy_value(spawn)
		result.enemies = _copy_value(enemies)
		result.timed_spawns = _copy_value(timed_spawns)
		result.stages = _copy_value(stages)
		return result


## 判断 JSON key 是否是注释(下划线开头)
static func _is_comment_key(key: String) -> bool:
	return key.begins_with("_")


## 从 dict 构造 ShapeParams 子类对象
## JSON 里 angle 用角度存,这里转成弧度(代码计算用)
static func _build_shape_params(shape_type: String, params_dict: Dictionary) -> Variant:
	match shape_type:
		ShapeType_SECTOR:
			var p = SectorParams.new()
			p.radius = float(params_dict.get("radius", 35.0))
			# 角度→弧度:rad = deg * π / 180
			p.angle = deg_to_rad(float(params_dict.get("angle", 120.0)))
			return p
		ShapeType_CIRCLE:
			var p = CircleParams.new()
			p.radius = float(params_dict.get("radius", 24.0))
			return p
		ShapeType_RECT:
			var p = RectParams.new()
			p.width = float(params_dict.get("width", 0.0))
			p.length = float(params_dict.get("length", 0.0))
			p.distance = float(params_dict.get("distance", 0.0))
			return p
		_:
			return null


## 从 dict 构造 AttackShape 对象
static func _build_attack_shape(shape_dict: Dictionary) -> AttackShape:
	var s = AttackShape.new()
	s.shape = shape_dict.get("shape", ShapeType_SECTOR)
	s.shape_params = _build_shape_params(s.shape, shape_dict.get("params", {}))
	s.duration = int(shape_dict.get("duration", 583))
	s.hit_time = int(shape_dict.get("hit_time", 83))
	s.damage_multiplier = float(shape_dict.get("damage_multiplier", 1.0))
	s.knockback_distance = float(shape_dict.get("knockback_distance", 0.0))
	return s


## 从 dict 构造 AttackConfig 对象
static func _build_attack_config(entry_dict: Dictionary) -> AttackConfig:
	var cfg = AttackConfig.new()
	for shape_dict in entry_dict.get("shape_list", []):
		cfg.shape_list.append(_build_attack_shape(shape_dict))
	cfg.colldown_ms = int(entry_dict.get("colldown_ms", 500))
	return cfg


## 从 dict 构造 CombatStats 对象(未配 combat_stats 时返回零值默认)
static func _build_combat_stats(stats_dict: Dictionary) -> CombatStats:
	var s = CombatStats.new()
	if stats_dict.is_empty():
		return s
	s.max_hp = int(stats_dict.get("max_hp", 0))
	s.attack_power = int(stats_dict.get("attack_power", 0))
	s.defense = int(stats_dict.get("defense", 0))
	return s


## 从 dict 构造 EntityCapability 对象
static func _build_entity_capability(entry_dict: Dictionary) -> EntityCapability:
	var cap = EntityCapability.new()
	var caps_dict: Dictionary = entry_dict.get("capabilities", {})
	cap.can_move = bool(caps_dict.get("can_move", false))
	cap.can_attack = bool(caps_dict.get("can_attack", false))
	cap.can_be_hurt = bool(caps_dict.get("can_be_hurt", false))
	cap.can_disconnect = bool(caps_dict.get("can_disconnect", false))
	cap.can_die = bool(caps_dict.get("can_die", false))
	cap.body_shape = entry_dict.get("body_shape", ShapeType_CIRCLE)
	cap.body_params = _build_shape_params(cap.body_shape, entry_dict.get("body_params", {}))
	cap.hit_layer = int(entry_dict.get("hit_layer", 0x00000000))
	cap.attack_mask = int(entry_dict.get("attack_mask", 0x00000000))
	cap.speed = float(entry_dict.get("speed", 0.0))
	cap.dead_duration_ms = int(entry_dict.get("dead_duration_ms", 0))
	cap.combat_stats = _build_combat_stats(entry_dict.get("combat_stats", {}))
	cap.body_color = entry_dict.get("body_color", "#8f0d6e")
	return cap


## 从 dict 构造 TerrainCapability 对象(未配 walkable 时默认可通行,安全默认)
static func _build_terrain_capability(entry_dict: Dictionary) -> TerrainCapability:
	var cap = TerrainCapability.new()
	cap.walkable = bool(entry_dict.get("walkable", true))
	cap.move_cost = int(entry_dict.get("move_cost", 1))
	return cap

## 从 dict 构造 NavigationMap 对象
static func _build_navigation_map(entry_dict: Dictionary) -> NavigationMap:
	var map = NavigationMap.new()
	map.map_id = entry_dict.get("map_id", "")
	map.terrain_ids.append_array(entry_dict.get("terrain_ids", []))
	map.tile_size_px = Vector2i(entry_dict.get("tile_size_px", [16, 16])[0], entry_dict.get("tile_size_px", [16, 16])[1])
	map.block_bounds_start = Vector2i(
		entry_dict.get("block_bounds", {}).get("min_inclusive", [0, 0])[0], 
		entry_dict.get("block_bounds", {}).get("min_inclusive", [0, 0])[1]
	)
	map.block_bounds_end = Vector2i(
		entry_dict.get("block_bounds", {}).get("max_exclusive", [10, 10])[0], 
		entry_dict.get("block_bounds", {}).get("max_exclusive", [10, 10])[1]
	)
	map.block_size = Vector2i(entry_dict.get("block_size", [2, 2])[0], entry_dict.get("block_size", [2, 2])[1])
	return map


## 解析 RewardEffect，嵌套结构统一构造为类型对象。
static func _build_reward_effect(entry: Dictionary) -> RewardEffect:
	var cfg := RewardEffect.new()
	cfg.stat = String(entry.get("stat", ""))
	cfg.operation = String(entry.get("operation", ""))
	cfg.value = float(entry.get("value", 0.0))
	return cfg


## 解析 RewardDefinition，嵌套结构统一构造为类型对象。
static func _build_reward_definition(entry: Dictionary, reward_id: String) -> RewardDefinition:
	var cfg := RewardDefinition.new()
	cfg.reward_id = reward_id
	cfg.name = String(entry.get("name", ""))
	cfg.description = String(entry.get("description", ""))
	cfg.weight = float(entry.get("weight", 0.0))
	var max_stacks: Variant = entry.get("max_stacks")
	cfg.max_stacks = null if max_stacks == null else int(max_stacks)
	for item in entry.get("effects", []):
		cfg.effects.append(_build_reward_effect(item))
	return cfg


## 解析 RewardProgression，嵌套结构统一构造为类型对象。
static func _build_reward_progression(entry: Dictionary) -> RewardProgression:
	var cfg := RewardProgression.new()
	cfg.initial_level = int(entry.get("initial_level", 0))
	cfg.max_level = int(entry.get("max_level", 0))
	for item in entry.get("next_level_xp", []):
		cfg.next_level_xp.append(int(item))
	cfg.base_pickup_radius_px = float(entry.get("base_pickup_radius_px", 0.0))
	cfg.collect_dropped_xp_on_stage_end = bool(entry.get("collect_dropped_xp_on_stage_end", false))
	cfg.overflow_policy = String(entry.get("overflow_policy", ""))
	return cfg


## 解析 RewardChoice，嵌套结构统一构造为类型对象。
static func _build_reward_choice(entry: Dictionary) -> RewardChoice:
	var cfg := RewardChoice.new()
	cfg.option_count = int(entry.get("option_count", 0))
	cfg.timeout_ms = int(entry.get("timeout_ms", 0))
	cfg.pause_single_player = bool(entry.get("pause_single_player", false))
	cfg.pause_multiplayer = bool(entry.get("pause_multiplayer", false))
	for item in entry.get("pool", []):
		cfg.pool.append(String(item))
	for item in entry.get("guaranteed_any_of", []):
		cfg.guaranteed_any_of.append(String(item))
	for item in entry.get("auto_choice_priority", []):
		cfg.auto_choice_priority.append(String(item))
	cfg.fallback_reward_id = String(entry.get("fallback_reward_id", ""))
	cfg.fallback_max_per_choice = int(entry.get("fallback_max_per_choice", 0))
	cfg.allow_fewer_options = bool(entry.get("allow_fewer_options", false))
	cfg.empty_choice_policy = String(entry.get("empty_choice_policy", ""))
	return cfg


## 解析 RewardEffectRules，嵌套结构统一构造为类型对象。
static func _build_reward_effect_rules(entry: Dictionary) -> RewardEffectRules:
	var cfg := RewardEffectRules.new()
	cfg.add_base_ratio = String(entry.get("add_base_ratio", ""))
	cfg.add_flat = String(entry.get("add_flat", ""))
	cfg.heal_flat = String(entry.get("heal_flat", ""))
	cfg.heal_max_hp_ratio = String(entry.get("heal_max_hp_ratio", ""))
	cfg.attack_range = String(entry.get("attack_range", ""))
	return cfg


## 解析 KillReward，嵌套结构统一构造为类型对象。
static func _build_kill_reward(entry: Dictionary) -> KillReward:
	var cfg := KillReward.new()
	cfg.xp = int(entry.get("xp", 0))
	cfg.delivery = String(entry.get("delivery", ""))
	cfg.bundle_id = String(entry.get("bundle_id", ""))
	return cfg


## 解析 RewardBundle，嵌套结构统一构造为类型对象。
static func _build_reward_bundle(entry: Dictionary) -> RewardBundle:
	var cfg := RewardBundle.new()
	cfg.max_grants_per_run = int(entry.get("max_grants_per_run", 0))
	for item in entry.get("effects", []):
		cfg.effects.append(_build_reward_effect(item))
	return cfg


## 解析 RewardSettlement，嵌套结构统一构造为类型对象。
static func _build_reward_settlement(entry: Dictionary) -> RewardSettlement:
	var cfg := RewardSettlement.new()
	cfg.completed_normal_stage_score = int(entry.get("completed_normal_stage_score", 0))
	cfg.elite_kill_score = int(entry.get("elite_kill_score", 0))
	cfg.boss_kill_score = int(entry.get("boss_kill_score", 0))
	cfg.reset_progression_on_restart = bool(entry.get("reset_progression_on_restart", false))
	return cfg


## 解析 RewardConfig，嵌套结构统一构造为类型对象。
static func _build_reward_config(entry: Dictionary) -> RewardConfig:
	var cfg := RewardConfig.new()
	cfg.schema_version = int(entry.get("schema_version", 0))
	cfg.progression = _build_reward_progression(entry.get("progression", {}))
	cfg.choice = _build_reward_choice(entry.get("choice", {}))
	cfg.effect_rules = _build_reward_effect_rules(entry.get("effect_rules", {}))
	var rewards: Dictionary = entry.get("rewards", {})
	for key in rewards:
		cfg.rewards[String(key)] = _build_reward_definition(rewards.get(key, {}), String(key))
	var kill_rewards: Dictionary = entry.get("kill_rewards", {})
	for key in kill_rewards:
		cfg.kill_rewards[String(key)] = _build_kill_reward(kill_rewards.get(key, {}))
	var bundles: Dictionary = entry.get("bundles", {})
	for key in bundles:
		cfg.bundles[String(key)] = _build_reward_bundle(bundles.get(key, {}))
	cfg.settlement = _build_reward_settlement(entry.get("settlement", {}))
	return cfg


## 解析 SurvivalRun，嵌套结构统一构造为类型对象。
static func _build_survival_run(entry: Dictionary) -> SurvivalRun:
	var cfg := SurvivalRun.new()
	cfg.start_on_first_player = bool(entry.get("start_on_first_player", false))
	cfg.min_players = int(entry.get("min_players", 0))
	cfg.max_players = int(entry.get("max_players", 0))
	cfg.late_join_policy = String(entry.get("late_join_policy", ""))
	cfg.advance_stage_policy = String(entry.get("advance_stage_policy", ""))
	cfg.victory_condition = String(entry.get("victory_condition", ""))
	cfg.timeout_result = String(entry.get("timeout_result", ""))
	cfg.all_players_dead_result = String(entry.get("all_players_dead_result", ""))
	for item in entry.get("same_tick_priority", []):
		cfg.same_tick_priority.append(String(item))
	cfg.reference_player_attack_id = int(entry.get("reference_player_attack_id", 0))
	return cfg


## 解析 SurvivalMultiplayer，嵌套结构统一构造为类型对象。
static func _build_survival_multiplayer(entry: Dictionary) -> SurvivalMultiplayer:
	var cfg := SurvivalMultiplayer.new()
	cfg.lock_player_count_at_start = bool(entry.get("lock_player_count_at_start", false))
	cfg.normal_budget_multiplier_per_player = float(entry.get("normal_budget_multiplier_per_player", 0.0))
	cfg.normal_alive_cap_multiplier_per_player = float(entry.get("normal_alive_cap_multiplier_per_player", 0.0))
	cfg.normal_spawn_rate_multiplier_per_player = float(entry.get("normal_spawn_rate_multiplier_per_player", 0.0))
	cfg.special_hp_extra_per_additional_player = float(entry.get("special_hp_extra_per_additional_player", 0.0))
	cfg.normal_xp_distribution = String(entry.get("normal_xp_distribution", ""))
	cfg.stage_xp_distribution = String(entry.get("stage_xp_distribution", ""))
	return cfg


## 解析 SpecialAliveCaps，嵌套结构统一构造为类型对象。
static func _build_special_alive_caps(entry: Dictionary) -> SpecialAliveCaps:
	var cfg := SpecialAliveCaps.new()
	cfg.elite = int(entry.get("elite", 0))
	cfg.boss = int(entry.get("boss", 0))
	return cfg


## 解析 NormalStagePulse，嵌套结构统一构造为类型对象。
static func _build_normal_stage_pulse(entry: Dictionary) -> NormalStagePulse:
	var cfg := NormalStagePulse.new()
	cfg.opening_seconds = float(entry.get("opening_seconds", 0.0))
	cfg.closing_seconds = float(entry.get("closing_seconds", 0.0))
	cfg.opening_rate_multiplier = float(entry.get("opening_rate_multiplier", 0.0))
	cfg.middle_rate_multiplier = float(entry.get("middle_rate_multiplier", 0.0))
	cfg.closing_rate_multiplier = float(entry.get("closing_rate_multiplier", 0.0))
	return cfg


## 解析 SpawnPosition，嵌套结构统一构造为类型对象。
static func _build_spawn_position(entry: Dictionary) -> SpawnPosition:
	var cfg := SpawnPosition.new()
	cfg.require_outside_all_alive_views = bool(entry.get("require_outside_all_alive_views", false))
	cfg.spawn_distance_min_px = float(entry.get("spawn_distance_min_px", 0.0))
	cfg.spawn_distance_max_px = float(entry.get("spawn_distance_max_px", 0.0))
	cfg.minimum_approach_seconds = float(entry.get("minimum_approach_seconds", 0.0))
	cfg.require_walkable = bool(entry.get("require_walkable", false))
	cfg.require_reachable_player = bool(entry.get("require_reachable_player", false))
	cfg.max_position_attempts = int(entry.get("max_position_attempts", 0))
	cfg.failure_policy = String(entry.get("failure_policy", ""))
	return cfg


## 解析 SpawnRecycle，嵌套结构统一构造为类型对象。
static func _build_spawn_recycle(entry: Dictionary) -> SpawnRecycle:
	var cfg := SpawnRecycle.new()
	for item in entry.get("roles", []):
		cfg.roles.append(String(item))
	cfg.outside_view_margin_px = float(entry.get("outside_view_margin_px", 0.0))
	cfg.preserve_instance_state = bool(entry.get("preserve_instance_state", false))
	cfg.grant_rewards = bool(entry.get("grant_rewards", false))
	return cfg


## 解析 SurvivalSpawn，嵌套结构统一构造为类型对象。
static func _build_survival_spawn(entry: Dictionary) -> SurvivalSpawn:
	var cfg := SurvivalSpawn.new()
	cfg.spawn_check_interval_seconds = float(entry.get("spawn_check_interval_seconds", 0.0))
	cfg.max_normal_spawns_per_second = int(entry.get("max_normal_spawns_per_second", 0))
	cfg.budget_carry_seconds = float(entry.get("budget_carry_seconds", 0.0))
	cfg.budget_carry_min_enemy_count = int(entry.get("budget_carry_min_enemy_count", 0))
	cfg.clear_budget_on_stage_change = bool(entry.get("clear_budget_on_stage_change", false))
	cfg.special_alive_caps = _build_special_alive_caps(entry.get("special_alive_caps", {}))
	cfg.normal_stage_pulse = _build_normal_stage_pulse(entry.get("normal_stage_pulse", {}))
	cfg.position = _build_spawn_position(entry.get("position", {}))
	cfg.recycle = _build_spawn_recycle(entry.get("recycle", {}))
	return cfg


## 解析 SurvivalEnemy，嵌套结构统一构造为类型对象。
static func _build_survival_enemy(entry: Dictionary) -> SurvivalEnemy:
	var cfg := SurvivalEnemy.new()
	cfg.role = String(entry.get("role", ""))
	cfg.spawn_cost = int(entry.get("spawn_cost", 0))
	cfg.apply_stage_scaling = bool(entry.get("apply_stage_scaling", false))
	return cfg


## 解析 TimedSpawn，嵌套结构统一构造为类型对象。
static func _build_timed_spawn(entry: Dictionary) -> TimedSpawn:
	var cfg := TimedSpawn.new()
	cfg.event_id = String(entry.get("event_id", ""))
	cfg.at_combat_seconds = float(entry.get("at_combat_seconds", 0.0))
	cfg.enemy_type = String(entry.get("enemy_type", ""))
	cfg.cap_reached_policy = String(entry.get("cap_reached_policy", ""))
	return cfg


## 解析 EntrySpawn，嵌套结构统一构造为类型对象。
static func _build_entry_spawn(entry: Dictionary) -> EntrySpawn:
	var cfg := EntrySpawn.new()
	cfg.event_id = String(entry.get("event_id", ""))
	cfg.enemy_type = String(entry.get("enemy_type", ""))
	cfg.position_failure_policy = String(entry.get("position_failure_policy", ""))
	return cfg


## 解析 SpawnPoolEntry，嵌套结构统一构造为类型对象。
static func _build_spawn_pool_entry(entry: Dictionary) -> SpawnPoolEntry:
	var cfg := SpawnPoolEntry.new()
	cfg.enemy_type = String(entry.get("enemy_type", ""))
	cfg.budget_share = float(entry.get("budget_share", 0.0))
	return cfg


## 解析 SurvivalStage，嵌套结构统一构造为类型对象。
static func _build_survival_stage(entry: Dictionary) -> SurvivalStage:
	var cfg := SurvivalStage.new()
	cfg.stage_id = int(entry.get("stage_id", 0))
	cfg.name = String(entry.get("name", ""))
	cfg.duration_seconds = float(entry.get("duration_seconds", 0.0))
	cfg.normal_budget_per_minute = float(entry.get("normal_budget_per_minute", 0.0))
	cfg.normal_alive_cap = int(entry.get("normal_alive_cap", 0))
	cfg.use_normal_stage_pulse = bool(entry.get("use_normal_stage_pulse", false))
	cfg.hp_multiplier = float(entry.get("hp_multiplier", 0.0))
	cfg.attack_multiplier = float(entry.get("attack_multiplier", 0.0))
	cfg.completion_xp = int(entry.get("completion_xp", 0))
	for item in entry.get("pool", []):
		cfg.pool.append(_build_spawn_pool_entry(item))
	for item in entry.get("clear_roles_on_entry", []):
		cfg.clear_roles_on_entry.append(String(item))
	cfg.grant_rewards_for_entry_clear = bool(entry.get("grant_rewards_for_entry_clear", false))
	var entry_spawn: Variant = entry.get("entry_spawn")
	if entry_spawn != null and not entry_spawn.is_empty():
		cfg.entry_spawn = _build_entry_spawn(entry_spawn)
	return cfg


## 解析 SurvivalConfig，嵌套结构统一构造为类型对象。
static func _build_survival_config(entry: Dictionary) -> SurvivalConfig:
	var cfg := SurvivalConfig.new()
	cfg.schema_version = int(entry.get("schema_version", 0))
	cfg.balance_version = String(entry.get("balance_version", ""))
	cfg.run = _build_survival_run(entry.get("run", {}))
	cfg.multiplayer = _build_survival_multiplayer(entry.get("multiplayer", {}))
	cfg.spawn = _build_survival_spawn(entry.get("spawn", {}))
	var enemies: Dictionary = entry.get("enemies", {})
	for key in enemies:
		cfg.enemies[String(key)] = _build_survival_enemy(enemies.get(key, {}))
	for item in entry.get("timed_spawns", []):
		cfg.timed_spawns.append(_build_timed_spawn(item))
	for item in entry.get("stages", []):
		cfg.stages.append(_build_survival_stage(item))
	return cfg


## 读取 res://config/ 下的 JSON 文件
static func _load_json(filename: String) -> Dictionary:
	var path: String = "res://config/" + filename
	if not FileAccess.file_exists(path):
		push_error("ConfigLoader: 配置文件不存在: " + path)
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	var json = JSON.new()
	var err = json.parse(text)
	if err != OK:
		push_error("ConfigLoader: JSON 解析失败 " + path + ": " + json.get_error_message())
		return {}
	if not json.data is Dictionary:
		push_error("ConfigLoader: JSON 顶层必须是对象: " + path)
		return {}
	return json.data

# ===========================================================================
# 配置缓存(首次访问时懒加载,因为 GDScript const 不能 new 对象)
# ===========================================================================
static var _attack_config_cache: Dictionary = {}     # {atk_id: AttackConfig}
static var _entity_capability_cache: Dictionary = {} # {entity_type: EntityCapability}
static var _terrain_capability_cache: Dictionary = {} # {terrain_name: TerrainCapability}
static var _vision_cache: Dictionary = {}            # {mode: VisionInfo}(normal/chase)
static var _constants_cache: Dictionary = {}
static var _cache_loaded: bool = false
static var _navigation_map_cache: Dictionary = {} # {map_id: NavigationMap}
static var _reward_config: RewardConfig = null
static var _survival_config: SurvivalConfig = null
static var _entity_visual_cache: Dictionary = {}



## 懒加载所有配置(只在首次访问时调一次)
static func _ensure_cache() -> void:
	if _cache_loaded:
		return

	# 攻击配置
	var attack_raw: Dictionary = _load_json("attack_config.json")
	for key in attack_raw.keys():
		if _is_comment_key(key):
			continue  # 跳过 _comment / _shape_type_values 等注释字段
		# atk_id 字符串 → int
		var atk_id = int(key)
		if str(atk_id) != key:
			continue  # 跳过非数字 key(防御性)
		_attack_config_cache[atk_id] = _build_attack_config(attack_raw[key])

	# 实体配置
	var entity_raw: Dictionary = _load_json("entity_config.json")
	for key in entity_raw.keys():
		if _is_comment_key(key):
			continue
		_entity_capability_cache[key] = _build_entity_capability(entity_raw[key])
		_entity_visual_cache[key] = _without_comments(entity_raw[key].get("visual", {}))

	# 地形配置
	# terrain_config.json 顶层只有 "terrains" 一个数据字段(其余是 _comment 等注释)
	var terrain_raw: Dictionary = _load_json("terrain_config.json")
	var terrains_dict: Dictionary = terrain_raw.get("terrains", {})
	for key in terrains_dict.keys():
		if _is_comment_key(key):
			continue
		_terrain_capability_cache[key] = _build_terrain_capability(terrains_dict[key])

	# 视野配置(敌人视锥)
	# vision_config.json 顶层是 normal/chase 两个数据段(其余是 _comment 等注释)
	# JSON 里 half_angle_deg 用角度存,这里转弧度(和服务端 config_loader 一致)
	var vision_raw: Dictionary = _load_json("vision_config.json")
	for key in vision_raw.keys():
		if _is_comment_key(key):
			continue
		var vision = VisionInfo.new()
		vision.half_angle = deg_to_rad(float(vision_raw[key].get("half_angle_deg", 30.0)))
		vision.radius = float(vision_raw[key].get("radius", 750.0))
		_vision_cache[key] = vision

	# 常量
	var constants_raw: Dictionary = _load_json("constants.json")
	for key in constants_raw.keys():
		if _is_comment_key(key):
			continue
		_constants_cache[key] = constants_raw[key]

	var reward_raw: Dictionary = _without_comments(_load_json("reward_config.json"))
	var survival_raw: Dictionary = _without_comments(_load_json("survival_config.json"))
	_reward_config = _build_reward_config(reward_raw)
	_survival_config = _build_survival_config(survival_raw)
	_cache_loaded = true


## 递归移除说明字段，返回可以独立修改的数据副本。
static func _without_comments(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			if not String(key).begins_with("_"):
				result[key] = _without_comments(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_without_comments(item))
		return result
	return value


## 奖励和生存返回类型对象的递归副本，避免调用方修改共享缓存。
static func get_reward_config() -> RewardConfig:
	_ensure_cache()
	if _reward_config == null:
		return null
	return _reward_config.copy() as RewardConfig


static func get_reward_definition(reward_id: String) -> RewardDefinition:
	_ensure_cache()
	if _reward_config == null:
		return null
	if not _reward_config.rewards.has(reward_id):
		push_error("奖励配置不存在: " + reward_id)
		return null
	return _reward_config.rewards[reward_id].copy() as RewardDefinition


static func get_survival_config() -> SurvivalConfig:
	_ensure_cache()
	if _survival_config == null:
		return null
	return _survival_config.copy() as SurvivalConfig


static func get_survival_stage(stage_id: int) -> SurvivalStage:
	_ensure_cache()
	if _survival_config == null:
		return null
	if stage_id < 1 or stage_id > _survival_config.stages.size():
		push_error("生存阶段不存在: %d" % stage_id)
		return null
	return _survival_config.stages[stage_id - 1].copy() as SurvivalStage


static func get_entity_visual_config(entity_config_key: String) -> Dictionary:
	_ensure_cache()
	return _entity_visual_cache.get(entity_config_key, {}).duplicate(true)


static func _load_navigation_map():
	var filenames := ["navigation_test_map.json"]
	for filename in filenames:
		var raw: Dictionary = _load_json(filename)
		var map = _build_navigation_map(raw)
		_navigation_map_cache[map.map_id] = map

# ===========================================================================
# 对外 API(和服务端 config_loader.py 对齐)
# ===========================================================================

## 获取某个 atk_id 的攻击配置(含 shape_list);未知返回 null
static func get_attack_config(atk_id: int) -> Variant:
	_ensure_cache()
	return _attack_config_cache.get(atk_id, null)


## 获取全部攻击配置(只读视图,不要修改返回的 dict)
static func get_all_attack_configs() -> Dictionary:
	_ensure_cache()
	return _attack_config_cache


## 取某个类型的能力配置(含碰撞形状)。
## 未列在表里的类型返回"零能力"配置(安全默认值),不会返回 null。
static func get_capability(entity_type: String) -> EntityCapability:
	_ensure_cache()
	return _entity_capability_cache.get(entity_type, EntityCapability.new())


## 取某个类型的基础战斗属性(max_hp/attack_power/defense)。
## 未列在表里的类型返回零值 CombatStats(max_hp=0 → 直接死,bug 早暴露)。
## 返回的是配置里的对象,调用方不要修改;EntityInfo 初始化时应该自己拷贝一份。
static func get_combat_stats(entity_type: String) -> CombatStats:
	_ensure_cache()
	var cap: EntityCapability = _entity_capability_cache.get(entity_type, EntityCapability.new())
	return cap.combat_stats


## 取某个类型的移动速度(像素/秒)。
## 未列在表里的类型返回 0(不会动,安全默认值)。
## LocalPlayerController 算每帧步长走这里。
static func get_speed(entity_type: String) -> float:
	_ensure_cache()
	var cap: EntityCapability = _entity_capability_cache.get(entity_type, EntityCapability.new())
	return cap.speed


## 取全局常量(如 HURT_DURATION_MS);未知返回 default
static func get_constant(name: String, default: Variant = null) -> Variant:
	_ensure_cache()
	return _constants_cache.get(name, default)


## 取 hurt 硬直时长(毫秒),语法糖
static func get_hurt_duration_ms() -> int:
	_ensure_cache()
	return int(_constants_cache.get("HURT_DURATION_MS", 666))


# ===========================================================================
# 地形能力 API(寻路用,和服务端 config_loader.py 对齐)
# ===========================================================================

## 取某个地形名称的能力配置。
## 未列在表里的地形返回默认值(walkable=true,安全默认)。
static func get_terrain_capability(terrain_name: String) -> TerrainCapability:
	_ensure_cache()
	var cap: Variant = _terrain_capability_cache.get(terrain_name)
	if cap == null:
		return TerrainCapability.new()
	return cap


## 判定某个 tile 类型是否可通行(客户端调试/可视化寻路用)。
## terrain_id 是 ChunkGenerator.get_tile_type_v3 返回值(int)。
## 未知 ID 默认 true(和服务端一致,安全默认)。
## 注意:寻路权威在服务端,客户端这个 API 仅用于调试可视化或预测显示。
static func is_walkable(terrain_id: int) -> bool:
	_ensure_cache()
	var terrain_name: String = _TERRAIN_ID_TO_NAME.get(terrain_id, "")
	if terrain_name == "":
		push_warning("is_walkable 收到未知 terrain_id=%d,默认返回 true" % terrain_id)
		return true
	var cap: TerrainCapability = _terrain_capability_cache.get(terrain_name)
	if cap == null:
		return true  # 未配置的地形默认可通行
	return cap.walkable


# ===========================================================================
# 视野(视锥)API(和服务端 config_loader.get_vision 对称)
# ===========================================================================

## 取敌人视野(视锥)配置。
## mode: "normal"(常态:除 chase 外的所有 AI 状态,如 patrol/look_around/attack)/
##        "chase"(追逐态,窄而远)。未知 mode 回退 normal(安全默认)。
## 返回 VisionInfo(half_angle 弧度 / radius 像素)。VisionFan 渲染视锥用。
static func get_vision(mode: String = "normal") -> VisionInfo:
	_ensure_cache()
	var vision: Variant = _vision_cache.get(mode)
	if vision == null:
		vision = _vision_cache.get("normal")
	if vision == null:
		return VisionInfo.new()
	return vision


## 敌人视锥功能总开关(json_config/constants.json 的 VISION_ENABLED)。
## 默认 true(配置缺失时按开启处理,保持既有行为)。
## 关闭后:服务端敌人无视视锥追击最近玩家,客户端不挂载/不渲染视锥扇形
## (Role._setup_enemy 据此跳过 VisionFan 挂载,避免显示误导)。
static func is_vision_enabled() -> bool:
	_ensure_cache()
	return bool(_constants_cache.get("VISION_ENABLED", true))


static func get_navigation_map(map_id: String) -> NavigationMap:
	var map: NavigationMap = _navigation_map_cache.get(map_id, null)
	if not map:
		_load_navigation_map()
	map = _navigation_map_cache.get(map_id, null)
	if not map:
		push_error("get_navigation_map 未找到 map_id=%s" % map_id)
	return map


		
		
