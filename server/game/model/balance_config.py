# coding=utf-8
"""生存与奖励配置的只读数据模型及字段读取，不执行配置内容校验或玩法规则。"""

from dataclasses import dataclass


@dataclass(frozen=True)
class RewardEffect:
    """单项强化操作。"""
    stat: str
    operation: str
    value: float


@dataclass(frozen=True)
class RewardDefinition:
    """可选择的一种奖励。"""
    reward_id: str
    name: str
    description: str
    weight: float
    max_stacks: int | None
    effects: tuple[RewardEffect, ...]


@dataclass(frozen=True)
class RewardProgression:
    """局内等级、经验阈值与拾取规则。"""
    initial_level: int
    max_level: int
    next_level_xp: tuple[int, ...]
    base_pickup_radius_px: float
    collect_dropped_xp_on_stage_end: bool
    overflow_policy: str


@dataclass(frozen=True)
class RewardChoice:
    """候选奖励的抽取、暂停与超时规则。"""
    option_count: int
    timeout_ms: int
    pause_single_player: bool
    pause_multiplayer: bool
    pool: tuple[str, ...]
    guaranteed_any_of: tuple[str, ...]
    auto_choice_priority: tuple[str, ...]
    fallback_reward_id: str
    fallback_max_per_choice: int
    allow_fewer_options: bool
    empty_choice_policy: str


@dataclass(frozen=True)
class RewardEffectRules:
    """奖励操作的说明契约，不执行属性计算。"""
    add_base_ratio: str
    add_flat: str
    heal_flat: str
    heal_max_hp_ratio: str
    attack_range: str


@dataclass(frozen=True)
class KillReward:
    """一种怪物的击杀奖励与发放方式。"""
    xp: int
    delivery: str
    bundle_id: str


@dataclass(frozen=True)
class RewardBundle:
    """固定礼包的发放上限和效果。"""
    max_grants_per_run: int
    effects: tuple[RewardEffect, ...]


@dataclass(frozen=True)
class RewardSettlement:
    """结算积分与局内成长清理规则。"""
    completed_normal_stage_score: int
    elite_kill_score: int
    boss_kill_score: int
    reset_progression_on_restart: bool


@dataclass(frozen=True)
class RewardConfig:
    """完整奖励对象；字典仅用于按编号索引类型对象。"""
    schema_version: int
    progression: RewardProgression
    choice: RewardChoice
    effect_rules: RewardEffectRules
    rewards: dict[str, RewardDefinition]
    kill_rewards: dict[str, KillReward]
    bundles: dict[str, RewardBundle]
    settlement: RewardSettlement


@dataclass(frozen=True)
class SurvivalRun:
    """开局、阶段推进和胜负判定规则。"""

    start_on_first_player: bool
    '''开局是否等待第一个玩家加入'''

    min_players: int
    '''最小玩家人数'''
    
    max_players: int
    '''最大玩家人数'''

    late_join_policy: str
    '''晚加入玩家策略'''

    advance_stage_policy: str
    '''阶段推进策略'''

    victory_condition: str
    '''胜利条件'''

    timeout_result: str
    '''超时结果'''

    all_players_dead_result: str
    '''所有玩家死亡结果'''

    same_tick_priority: tuple[str, ...]
    '''相同 tick优先级'''

    reference_player_attack_id: int
    '''参考玩家攻击 ID'''


@dataclass(frozen=True)
class SurvivalMultiplayer:
    """按开局人数计算的强度、刷怪和经验规则。"""
    lock_player_count_at_start: bool
    normal_budget_multiplier_per_player: float
    normal_alive_cap_multiplier_per_player: float
    normal_spawn_rate_multiplier_per_player: float
    special_hp_extra_per_additional_player: float
    normal_xp_distribution: str
    stage_xp_distribution: str


@dataclass(frozen=True)
class SpecialAliveCaps:
    """精英和首领的独立存活上限。"""
    elite: int
    '''精英存活上限'''

    boss: int
    '''首领存活上限'''


@dataclass(frozen=True)
class NormalStagePulse:
    """普通阶段前、中、后三段的预算节奏。"""
    opening_seconds: float
    '''开始预算'''
    
    closing_seconds: float
    '''结束预算'''
    
    opening_rate_multiplier: float
    '''开始预算倍率'''
    
    middle_rate_multiplier: float
    '''中段预算倍率'''
    
    closing_rate_multiplier: float
    '''结束预算倍率'''


@dataclass(frozen=True)
class SpawnPosition:
    """出生点到所选玩家中心的距离、导航和尝试次数配置；距离使用世界单位。"""
    require_outside_all_alive_views: bool
    spawn_distance_min_px: float
    spawn_distance_max_px: float
    minimum_approach_seconds: float
    require_walkable: bool
    require_reachable_player: bool
    max_position_attempts: int
    failure_policy: str


@dataclass(frozen=True)
class SpawnRecycle:
    """远距离回收的角色范围和实例保留规则。"""
    roles: tuple[str, ...]
    outside_view_margin_px: float
    preserve_instance_state: bool
    grant_rewards: bool


@dataclass(frozen=True)
class SurvivalSpawn:
    """预算、生成频率、位置与回收配置。"""
    spawn_check_interval_seconds: float
    max_normal_spawns_per_second: int
    budget_carry_seconds: float
    budget_carry_min_enemy_count: int
    clear_budget_on_stage_change: bool
    special_alive_caps: SpecialAliveCaps
    normal_stage_pulse: NormalStagePulse
    position: SpawnPosition
    recycle: SpawnRecycle


@dataclass(frozen=True)
class SurvivalEnemy:
    """怪物在生存模式中的角色、价格和倍率开关。"""
    role: str
    spawn_cost: int
    apply_stage_scaling: bool


@dataclass(frozen=True)
class TimedSpawn:
    """按玩法时间独立投放的特殊怪事件。"""
    event_id: str
    at_combat_seconds: float
    enemy_type: str
    cap_reached_policy: str


@dataclass(frozen=True)
class EntrySpawn:
    """阶段进入时的首领投放事件。"""
    event_id: str
    enemy_type: str
    position_failure_policy: str


@dataclass(frozen=True)
class SpawnPoolEntry:
    """普通怪的预算分配，不代表生成数量占比。"""
    enemy_type: str
    budget_share: float
    '''预算分配占比'''


@dataclass(frozen=True)
class SurvivalStage:
    """一局中的单个阶段。"""
    stage_id: int
    name: str
    duration_seconds: float
    '''阶段时长'''

    normal_budget_per_minute: float
    '''每分钟刷怪预算'''

    normal_alive_cap: int
    '''普通怪物数量上限'''

    use_normal_stage_pulse: bool
    '''是否使用普通阶段节奏'''

    hp_multiplier: float
    '''生命值倍率'''

    attack_multiplier: float
    '''攻击倍率'''

    completion_xp: int
    '''击杀普通怪物掉落经验'''

    pool: tuple[SpawnPoolEntry, ...]
    '''普通怪物池'''
    clear_roles_on_entry: tuple[str, ...] = ()
    grant_rewards_for_entry_clear: bool = False
    entry_spawn: EntrySpawn | None = None


@dataclass(frozen=True)
class SurvivalConfig:
    """完整生存对象；阶段和事件按时间顺序保存。"""

    schema_version: int
    '''配置版本'''
    
    balance_version: str
    '''平衡版本'''

    run: SurvivalRun
    '''开局规则'''

    multiplayer: SurvivalMultiplayer
    '''多人规则'''

    spawn: SurvivalSpawn
    '''刷怪规则'''

    enemies: dict[str, SurvivalEnemy]
    '''敌人配置'''

    timed_spawns: tuple[TimedSpawn, ...]
    '''定时投放事件'''

    stages: tuple[SurvivalStage, ...]
    '''阶段配置'''

    @property
    def duration_seconds(self) -> float:
        """从阶段数据计算整局玩法时长，不维护重复常量。"""
        return sum(stage.duration_seconds for stage in self.stages)


def strip_comments(value):
    """递归移除配置说明字段，保留协议字段名和所有业务字段。"""
    if isinstance(value, dict):
        return {key: strip_comments(item) for key, item in value.items() if not key.startswith("_")}
    if isinstance(value, list):
        return [strip_comments(item) for item in value]
    return value


def _build_reward_effect(entry: dict) -> RewardEffect:
    """读取字段并构造 RewardEffect 对象。"""
    return RewardEffect(
        stat=str(entry.get("stat", "")),
        operation=str(entry.get("operation", "")),
        value=float(entry.get("value", 0.0)),
    )


def _build_reward_definition(entry: dict, reward_id: str) -> RewardDefinition:
    """读取字段并构造 RewardDefinition 对象。"""
    max_stacks = entry.get("max_stacks")
    return RewardDefinition(
        reward_id=reward_id,
        name=str(entry.get("name", "")),
        description=str(entry.get("description", "")),
        weight=float(entry.get("weight", 0.0)),
        max_stacks=None if max_stacks is None else int(max_stacks),
        effects=tuple(_build_reward_effect(item) for item in entry.get("effects", [])),
    )


def _build_reward_progression(entry: dict) -> RewardProgression:
    """读取字段并构造 RewardProgression 对象。"""
    return RewardProgression(
        initial_level=int(entry.get("initial_level", 0)),
        max_level=int(entry.get("max_level", 0)),
        next_level_xp=tuple(int(item) for item in entry.get("next_level_xp", [])),
        base_pickup_radius_px=float(entry.get("base_pickup_radius_px", 0.0)),
        collect_dropped_xp_on_stage_end=bool(entry.get("collect_dropped_xp_on_stage_end", False)),
        overflow_policy=str(entry.get("overflow_policy", "")),
    )


def _build_reward_choice(entry: dict) -> RewardChoice:
    """读取字段并构造 RewardChoice 对象。"""
    return RewardChoice(
        option_count=int(entry.get("option_count", 0)),
        timeout_ms=int(entry.get("timeout_ms", 0)),
        pause_single_player=bool(entry.get("pause_single_player", False)),
        pause_multiplayer=bool(entry.get("pause_multiplayer", False)),
        pool=tuple(str(item) for item in entry.get("pool", [])),
        guaranteed_any_of=tuple(str(item) for item in entry.get("guaranteed_any_of", [])),
        auto_choice_priority=tuple(str(item) for item in entry.get("auto_choice_priority", [])),
        fallback_reward_id=str(entry.get("fallback_reward_id", "")),
        fallback_max_per_choice=int(entry.get("fallback_max_per_choice", 0)),
        allow_fewer_options=bool(entry.get("allow_fewer_options", False)),
        empty_choice_policy=str(entry.get("empty_choice_policy", "")),
    )


def _build_reward_effect_rules(entry: dict) -> RewardEffectRules:
    """读取字段并构造 RewardEffectRules 对象。"""
    return RewardEffectRules(
        add_base_ratio=str(entry.get("add_base_ratio", "")),
        add_flat=str(entry.get("add_flat", "")),
        heal_flat=str(entry.get("heal_flat", "")),
        heal_max_hp_ratio=str(entry.get("heal_max_hp_ratio", "")),
        attack_range=str(entry.get("attack_range", "")),
    )


def _build_kill_reward(entry: dict) -> KillReward:
    """读取字段并构造 KillReward 对象。"""
    return KillReward(
        xp=int(entry.get("xp", 0)),
        delivery=str(entry.get("delivery", "")),
        bundle_id=str(entry.get("bundle_id", "")),
    )


def _build_reward_bundle(entry: dict) -> RewardBundle:
    """读取字段并构造 RewardBundle 对象。"""
    return RewardBundle(
        max_grants_per_run=int(entry.get("max_grants_per_run", 0)),
        effects=tuple(_build_reward_effect(item) for item in entry.get("effects", [])),
    )


def _build_reward_settlement(entry: dict) -> RewardSettlement:
    """读取字段并构造 RewardSettlement 对象。"""
    return RewardSettlement(
        completed_normal_stage_score=int(entry.get("completed_normal_stage_score", 0)),
        elite_kill_score=int(entry.get("elite_kill_score", 0)),
        boss_kill_score=int(entry.get("boss_kill_score", 0)),
        reset_progression_on_restart=bool(entry.get("reset_progression_on_restart", False)),
    )


def build_reward_config(entry: dict) -> RewardConfig:
    """读取字段并构造 RewardConfig 对象。"""
    entry = strip_comments(entry)
    return RewardConfig(
        schema_version=int(entry.get("schema_version", 0)),
        progression=_build_reward_progression(entry.get("progression", {})),
        choice=_build_reward_choice(entry.get("choice", {})),
        effect_rules=_build_reward_effect_rules(entry.get("effect_rules", {})),
        rewards={key: _build_reward_definition(item, key) for key, item in entry.get("rewards", {}).items()},
        kill_rewards={key: _build_kill_reward(item) for key, item in entry.get("kill_rewards", {}).items()},
        bundles={key: _build_reward_bundle(item) for key, item in entry.get("bundles", {}).items()},
        settlement=_build_reward_settlement(entry.get("settlement", {})),
    )


def _build_survival_run(entry: dict) -> SurvivalRun:
    """读取字段并构造 SurvivalRun 对象。"""
    return SurvivalRun(
        start_on_first_player=bool(entry.get("start_on_first_player", False)),
        min_players=int(entry.get("min_players", 0)),
        max_players=int(entry.get("max_players", 0)),
        late_join_policy=str(entry.get("late_join_policy", "")),
        advance_stage_policy=str(entry.get("advance_stage_policy", "")),
        victory_condition=str(entry.get("victory_condition", "")),
        timeout_result=str(entry.get("timeout_result", "")),
        all_players_dead_result=str(entry.get("all_players_dead_result", "")),
        same_tick_priority=tuple(str(item) for item in entry.get("same_tick_priority", [])),
        reference_player_attack_id=int(entry.get("reference_player_attack_id", 0)),
    )


def _build_survival_multiplayer(entry: dict) -> SurvivalMultiplayer:
    """读取字段并构造 SurvivalMultiplayer 对象。"""
    return SurvivalMultiplayer(
        lock_player_count_at_start=bool(entry.get("lock_player_count_at_start", False)),
        normal_budget_multiplier_per_player=float(entry.get("normal_budget_multiplier_per_player", 0.0)),
        normal_alive_cap_multiplier_per_player=float(entry.get("normal_alive_cap_multiplier_per_player", 0.0)),
        normal_spawn_rate_multiplier_per_player=float(entry.get("normal_spawn_rate_multiplier_per_player", 0.0)),
        special_hp_extra_per_additional_player=float(entry.get("special_hp_extra_per_additional_player", 0.0)),
        normal_xp_distribution=str(entry.get("normal_xp_distribution", "")),
        stage_xp_distribution=str(entry.get("stage_xp_distribution", "")),
    )


def _build_special_alive_caps(entry: dict) -> SpecialAliveCaps:
    """读取字段并构造 SpecialAliveCaps 对象。"""
    return SpecialAliveCaps(
        elite=int(entry.get("elite", 0)),
        boss=int(entry.get("boss", 0)),
    )


def _build_normal_stage_pulse(entry: dict) -> NormalStagePulse:
    """读取字段并构造 NormalStagePulse 对象。"""
    return NormalStagePulse(
        opening_seconds=float(entry.get("opening_seconds", 0.0)),
        closing_seconds=float(entry.get("closing_seconds", 0.0)),
        opening_rate_multiplier=float(entry.get("opening_rate_multiplier", 0.0)),
        middle_rate_multiplier=float(entry.get("middle_rate_multiplier", 0.0)),
        closing_rate_multiplier=float(entry.get("closing_rate_multiplier", 0.0)),
    )


def _build_spawn_position(entry: dict) -> SpawnPosition:
    """读取字段并构造 SpawnPosition 对象。"""
    return SpawnPosition(
        require_outside_all_alive_views=bool(entry.get("require_outside_all_alive_views", False)),
        spawn_distance_min_px=float(entry.get("spawn_distance_min_px", 0.0)),
        spawn_distance_max_px=float(entry.get("spawn_distance_max_px", 0.0)),
        minimum_approach_seconds=float(entry.get("minimum_approach_seconds", 0.0)),
        require_walkable=bool(entry.get("require_walkable", False)),
        require_reachable_player=bool(entry.get("require_reachable_player", False)),
        max_position_attempts=int(entry.get("max_position_attempts", 0)),
        failure_policy=str(entry.get("failure_policy", "")),
    )


def _build_spawn_recycle(entry: dict) -> SpawnRecycle:
    """读取字段并构造 SpawnRecycle 对象。"""
    return SpawnRecycle(
        roles=tuple(str(item) for item in entry.get("roles", [])),
        outside_view_margin_px=float(entry.get("outside_view_margin_px", 0.0)),
        preserve_instance_state=bool(entry.get("preserve_instance_state", False)),
        grant_rewards=bool(entry.get("grant_rewards", False)),
    )


def _build_survival_spawn(entry: dict) -> SurvivalSpawn:
    """读取字段并构造 SurvivalSpawn 对象。"""
    return SurvivalSpawn(
        spawn_check_interval_seconds=float(entry.get("spawn_check_interval_seconds", 0.0)),
        max_normal_spawns_per_second=int(entry.get("max_normal_spawns_per_second", 0)),
        budget_carry_seconds=float(entry.get("budget_carry_seconds", 0.0)),
        budget_carry_min_enemy_count=int(entry.get("budget_carry_min_enemy_count", 0)),
        clear_budget_on_stage_change=bool(entry.get("clear_budget_on_stage_change", False)),
        special_alive_caps=_build_special_alive_caps(entry.get("special_alive_caps", {})),
        normal_stage_pulse=_build_normal_stage_pulse(entry.get("normal_stage_pulse", {})),
        position=_build_spawn_position(entry.get("position", {})),
        recycle=_build_spawn_recycle(entry.get("recycle", {})),
    )


def _build_survival_enemy(entry: dict) -> SurvivalEnemy:
    """读取字段并构造 SurvivalEnemy 对象。"""
    return SurvivalEnemy(
        role=str(entry.get("role", "")),
        spawn_cost=int(entry.get("spawn_cost", 0)),
        apply_stage_scaling=bool(entry.get("apply_stage_scaling", False)),
    )


def _build_timed_spawn(entry: dict) -> TimedSpawn:
    """读取字段并构造 TimedSpawn 对象。"""
    return TimedSpawn(
        event_id=str(entry.get("event_id", "")),
        at_combat_seconds=float(entry.get("at_combat_seconds", 0.0)),
        enemy_type=str(entry.get("enemy_type", "")),
        cap_reached_policy=str(entry.get("cap_reached_policy", "")),
    )


def _build_entry_spawn(entry: dict) -> EntrySpawn:
    """读取字段并构造 EntrySpawn 对象。"""
    return EntrySpawn(
        event_id=str(entry.get("event_id", "")),
        enemy_type=str(entry.get("enemy_type", "")),
        position_failure_policy=str(entry.get("position_failure_policy", "")),
    )


def _build_spawn_pool_entry(entry: dict) -> SpawnPoolEntry:
    """读取字段并构造 SpawnPoolEntry 对象。"""
    return SpawnPoolEntry(
        enemy_type=str(entry.get("enemy_type", "")),
        budget_share=float(entry.get("budget_share", 0.0)),    
    )


def _build_survival_stage(entry: dict) -> SurvivalStage:
    """读取字段并构造 SurvivalStage 对象。"""
    entry_spawn = entry.get("entry_spawn")
    return SurvivalStage(
        stage_id=int(entry.get("stage_id", 0)),
        name=str(entry.get("name", "")),
        duration_seconds=float(entry.get("duration_seconds", 0.0)),
        normal_budget_per_minute=float(entry.get("normal_budget_per_minute", 0.0)),
        normal_alive_cap=int(entry.get("normal_alive_cap", 0)),
        use_normal_stage_pulse=bool(entry.get("use_normal_stage_pulse", False)),
        hp_multiplier=float(entry.get("hp_multiplier", 0.0)),
        attack_multiplier=float(entry.get("attack_multiplier", 0.0)),
        completion_xp=int(entry.get("completion_xp", 0)),
        pool=tuple(_build_spawn_pool_entry(item) for item in entry.get("pool", [])),
        clear_roles_on_entry=tuple(str(item) for item in entry.get("clear_roles_on_entry", [])),
        grant_rewards_for_entry_clear=bool(entry.get("grant_rewards_for_entry_clear", False)),
        entry_spawn=_build_entry_spawn(entry_spawn) if entry_spawn else None,
    )


def build_survival_config(entry: dict) -> SurvivalConfig:
    """读取字段并构造 SurvivalConfig 对象。"""
    entry = strip_comments(entry)
    return SurvivalConfig(
        schema_version=int(entry.get("schema_version", 0)),
        balance_version=str(entry.get("balance_version", "")),
        run=_build_survival_run(entry.get("run", {})),
        multiplayer=_build_survival_multiplayer(entry.get("multiplayer", {})),
        spawn=_build_survival_spawn(entry.get("spawn", {})),
        enemies={key: _build_survival_enemy(item) for key, item in entry.get("enemies", {}).items()},
        timed_spawns=tuple(_build_timed_spawn(item) for item in entry.get("timed_spawns", [])),
        stages=tuple(_build_survival_stage(item) for item in entry.get("stages", [])),
    )
