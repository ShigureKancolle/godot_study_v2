# coding=utf-8

import math
import random
import time


from game.entity_projector import project_entity_snapshot
from game.model.components import PlayerComponent, TransformComponent
from game.systems.game_mode.game_mode import GameMode
import game.commands as commands
import game.events as events
import game.model.config_loader as config_loader
import game.model.balance_config as balance_config
from dataclasses import dataclass
import typing
if typing.TYPE_CHECKING:
    import game.world as gw
    import game.command_router as command_router
    from game.model import entity

@dataclass
class SpawnBudgetData:
    """生成预算数据。"""
    budget: float
    '''预算金额'''

    budget_weight: float
    '''预算分配占比'''

@dataclass
class TimeSpawnData:
    """定时生成敌人"""
    spawn_time: int
    '''生成时间，开局第几毫秒'''

    enemy_type: str
    '''敌人类型ID'''

    is_spawned: bool = False
    '''是否已生成'''

class SurvivalMode(GameMode):
    """生存模式。"""

    def __init__(self):
        super().__init__()
        self._game_timestamp_ms = 0
        '''游戏计时，单位毫秒，整个生存模式的计时都以这个为准'''

        self._time_spawn_list: list[TimeSpawnData] = []
        self._survival_config = config_loader.get_survival_config()
        self._cur_stage = None
        # region stage数据 切换的时候要清空
        self._cur_budget = 0.0
        self._enemy_budget: dict[str, SpawnBudgetData] = {}
        self._stage_start_timestamp_ms = 0.0
        '''当前阶段开始时间'''
        self._next_stage_timestamp_ms = 0
        # endregion

        # 下次刷新怪物在这个tick之后检查是否需要刷新
        self._refresh_timestamp_ms = 0

        self._game_finished = False

    def start(self, world: "gw.GameWorld"):
        """开始游戏模式。"""
        super().start(world)
        # 开始计时 准备刷怪
        self._cur_stage = self._survival_config.stages[0]
        self._game_timestamp_ms = time.time() * 1000
        self._init_stage()
        self._init_timed_spawns()

    def _init_stage(self):
        """初始化当前阶段。"""
        # 阶段起点使用玩法时钟，暂停期间不会累计已用时间。
        self._stage_start_timestamp_ms = self._game_timestamp_ms
        self._refresh_timestamp_ms = self._game_timestamp_ms + self._survival_config.spawn.spawn_check_interval_seconds * 1000
        self._next_stage_timestamp_ms = self._game_timestamp_ms + self._cur_stage.duration_seconds * 1000
        total_weight = 0.0
        for enemy in self._cur_stage.pool:
            total_weight += enemy.budget_share

        self._enemy_budget: dict[str, SpawnBudgetData] = {}
        for enemy in self._cur_stage.pool:
            data = SpawnBudgetData(
                budget = 0,
                budget_weight = enemy.budget_share / total_weight,
            )
            self._enemy_budget[enemy.enemy_type] = data

        # 按生成消耗从高到低排序
        def sort(item):
            key = item[0]
            spawn_cost = self._survival_config.enemies[key].spawn_cost
            return spawn_cost

        self._enemy_budget = dict(sorted(self._enemy_budget.items(), key=sort, reverse=True))

        # 特殊生成
        if self._cur_stage.entry_spawn:
            # 这个是进入阶段立即生成 所以时间设为0
            self._time_spawn_list.append(TimeSpawnData(
                spawn_time = 0,
                enemy_type = self._cur_stage.entry_spawn.enemy_type,
            ))

        # todo 也许需要通知刷新ui

    def _next_stage(self):
        """切换到下一个阶段。"""
        # stages是list stage_id是索引+1
        if self._cur_stage.stage_id + 1 not in [stage.stage_id for stage in self._survival_config.stages]:
            # 应该结束游戏了
            self._game_finished = True
            return

        # 上面检查的是下一阶段是否存在 如果存在 那么下一阶段的索引就是这阶段id
        self._cur_stage = self._survival_config.stages[self._cur_stage.stage_id] 
        
        self._init_stage()

    def _init_timed_spawns(self):
        """初始化定时生成。"""
        self._time_spawn_list: list[TimeSpawnData] = []
        for time_spawns in self._survival_config.timed_spawns:
            self._time_spawn_list.append(TimeSpawnData(
                spawn_time = self._game_timestamp_ms + int(time_spawns.at_combat_seconds) * 1000,
                enemy_type = time_spawns.enemy_type,
            ))

    def before_step(self, world: "gw.GameWorld", dt: float) -> list[events.Event]:
        """在 tick 开始前调用。"""
        if not self.should_advance_gameplay():
            return []
        
        _before_step_events: list[events.Event] = []
        if self._game_finished:
            # 抛出结算游戏？
            return _before_step_events

        super().before_step(world, dt)
        self._game_timestamp_ms += dt * 1000
        self._budget_add(world, dt, _before_step_events)
        self._countdown_time(world, dt, _before_step_events)
        return _before_step_events


    def after_step(self, world: "gw.GameWorld", dt: float) -> list[events.Event]:
        """在 tick 结束后调用。"""
        if not self.should_advance_gameplay():
            return []

        if self._game_finished:
            return []

        _after_step_events: list[events.Event] = []
        super().after_step(world, dt)
        if self._try_next_stage(world, dt, _after_step_events):
            # 下一阶段事件
            return _after_step_events

        # 在帧最后刷新敌人， 给点反应时间
        self._try_spawn_enemy(world, dt, _after_step_events)
        return _after_step_events


    def register_command_handlers(self, router: "command_router.CommandRouter"):
        """注册当前游戏模式特有的命令处理函数。"""
        router.register(commands.RewardChoiceCommand, self._handle_reward_choice_command)

    def handle_player_join(self):
        """处理玩家加入。"""
        pass

    def handle_player_leave(self):
        """处理玩家离开。"""
        pass

    def is_finished(self) -> bool:
        """是否游戏结束。"""
        return False

    def clearup(self, world: "gw.GameWorld"):
        """清理游戏模式。"""
        pass   

    def _handle_reward_choice_command(self, command: commands.RewardChoiceCommand):
        """处理奖励选择命令。"""
        pass

    def _countdown_time(self, world: "gw.GameWorld", dt: float, evns: list[events.Event]):
        """倒计时。"""

        # 先不统一管理了 谁用谁维护

        pass

    def _budget_add(self, world: "gw.GameWorld", dt: float, evns: list[events.Event]):
        """添加预算。"""
        # 暂停了
        if not self.should_advance_gameplay():
            return

        # 是否使用阶段刷新
        use_stage_refresh = self._cur_stage.use_normal_stage_pulse

        if use_stage_refresh:
            # 当前是opening normal closing？
            state_seconds = 0
            is_opening = state_seconds < self._survival_config.spawn.normal_stage_pulse.opening_seconds
            is_closing = self._cur_stage.duration_seconds - state_seconds < self._survival_config.spawn.normal_stage_pulse.closing_seconds
            if is_opening:
                total_budget = \
                    self._cur_stage.normal_budget_per_minute / 60 * dt * \
                    self._survival_config.spawn.normal_stage_pulse.opening_rate_multiplier
            elif is_closing:
                total_budget = \
                    self._cur_stage.normal_budget_per_minute / 60 * dt * \
                    self._survival_config.spawn.normal_stage_pulse.closing_rate_multiplier
            else:
                total_budget = self._cur_stage.normal_budget_per_minute / 60 * dt * \
                    self._survival_config.spawn.normal_stage_pulse.middle_rate_multiplier
        else:
            total_budget = self._cur_stage.normal_budget_per_minute / 60 * dt * \
                self._survival_config.spawn.normal_stage_pulse.middle_rate_multiplier
       
        # 把预算按权重分配给每个敌人
        for enemy in self._cur_stage.pool:
            budget_data = self._enemy_budget[enemy.enemy_type]
            target_budget = budget_data.budget + total_budget * budget_data.budget_weight
            max_budget = self._survival_config.spawn.budget_carry_seconds * self._survival_config.enemies[enemy.enemy_type].spawn_cost
            budget_data.budget = min(target_budget, max_budget)

        # todo 同步

    def _try_spawn_enemy(self, world: "gw.GameWorld", dt: float, evns: list[events.Event]):
        """尝试生成敌人。"""
        # 检查间隔
        if self._refresh_timestamp_ms > self._game_timestamp_ms:
            return

        # 暂停了
        if not self.should_advance_gameplay():
            return

        self._refresh_timestamp_ms = self._game_timestamp_ms + self._survival_config.spawn.spawn_check_interval_seconds * 1000

        normal_enemy_type = ["enemy_slime", "enemy_skeleton", "enemy_runner"]

        spawn_count = 0
        for enemy_type, budget_data in self._enemy_budget.items():
            spawn_budget = self._survival_config.enemies[enemy_type].spawn_cost
            # 检查上限
            if world.enemy_count(normal_enemy_type) >= self._cur_stage.normal_alive_cap:
                break

            # 一次生成的普通敌人数量有限制
            if spawn_count >= self._survival_config.spawn.max_normal_spawns_per_second:
                break

            # 检查预算
            if budget_data.budget >= spawn_budget:
                if _enemy := self._real_spawn_enemy(world, enemy_type):
                    budget_data.budget -= spawn_budget
                    spawn_count += 1
                    evns.append(events.EntitySpawnedEvent(entity_info=project_entity_snapshot(_enemy)))

        # 特殊生成在没成功之前会一直尝试
        for time_spawn_data in self._time_spawn_list:
            if self._game_timestamp_ms >= time_spawn_data.spawn_time and not time_spawn_data.is_spawned:
                if _enemy := self._real_spawn_enemy(world, time_spawn_data.enemy_type):
                    time_spawn_data.is_spawned = True
                    evns.append(events.EntitySpawnedEvent(entity_info=project_entity_snapshot(_enemy)))


    def _real_spawn_enemy(self, world: "gw.GameWorld", enemy_type: str) -> "entity.Entity | None":
        """真实生成敌人。"""
        # 随便找一个玩家 生成在他周围
        players: list["entity.Entity"] = world.entities_with([PlayerComponent, TransformComponent])
        if not players:
            return None

        # 以这个玩家为圆心的环形范围生成敌人 但是要避开其他玩家的最近距离
        random_player: "entity.Entity" = random.Random().choice(players)
        player_x = random_player.get_component(TransformComponent).x
        player_y = random_player.get_component(TransformComponent).y

        # 10次都roll不到一个合适的位置 就放弃生成
        idx = 0
        while (idx < self._survival_config.spawn.position.max_position_attempts):
            # 随机一个方向和距离
            angle = random.Random().uniform(0, 2 * math.pi)
            distance = random.Random().uniform(self._survival_config.spawn.position.spawn_distance_min_px, 
                                            self._survival_config.spawn.position.spawn_distance_max_px)


            # 计算敌人位置
            enemy_x = player_x + distance * math.cos(angle)
            enemy_y = player_y + distance * math.sin(angle)

            # 判断是否在其他玩家禁区
            for player in players:
                _x = player.get_component(TransformComponent).x
                _y = player.get_component(TransformComponent).y
                if (enemy_x - _x) ** 2 + (enemy_y - _y) ** 2 < self._survival_config.spawn.position.spawn_distance_min_px ** 2:
                    # 在禁区
                    idx += 1
                    break

                _pos_walkable = world.pathfinder.is_walkable(enemy_x, enemy_y)
                if not _pos_walkable: 
                    # 目标点不能走
                    idx += 1
                    break

            else:
                break

        if idx >= self._survival_config.spawn.position.max_position_attempts:
            return None

        enemy = world.create_enemy(enemy_type, enemy_x, enemy_y)
        return enemy

    def _try_next_stage(self, world: "gw.GameWorld", dt: float, evns: list[events.Event]):
        """尝试切换到下一个阶段。"""
        if self._next_stage_timestamp_ms > self._game_timestamp_ms:
            return False
        self._next_stage()
        # evns.append(events.StageChangedEvent(stage=self._cur_stage))
        return True

    # region debug
    def skip_cur_stage(self):
        """跳过当前阶段。"""
        _game_timestamp_ms = self._next_stage_timestamp_ms - 5000
        if self._game_timestamp_ms < _game_timestamp_ms:
            self._game_timestamp_ms = _game_timestamp_ms

    # endregion
