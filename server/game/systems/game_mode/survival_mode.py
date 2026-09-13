# coding=utf-8

import math
import random


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

class SurvivalMode(GameMode):
    """生存模式。"""

    def __init__(self):
        super().__init__()
        self._survival_config = config_loader.get_survival_config()
        self._cur_stage = None
        # 当前预算
        self._cur_budget = 0.0
        self._enemy_budget: dict[str, ] = {}

    def start(self, world: "gw.GameWorld"):
        """开始游戏模式。"""
        super().start(world)
        # 开始计时 准备刷怪
        self._cur_stage = self._survival_config.stages[0]
        self._enemy_budget: dict[str, SpawnBudgetData] = {}
        self._init_stage()

    def _init_stage(self):
        """初始化当前阶段。"""
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

    def _next_stage(self):
        """切换到下一个阶段。"""
        if self._cur_stage.stage_id + 1 not in [stage.stage_id for stage in self._survival_config.stages]:
            # 应该结束游戏了
            self._game_finished = True

        self._cur_stage = self._survival_config.stages[self._cur_stage.stage_id + 1] 
        
        self._init_stage()


    def before_step(self, world: "gw.GameWorld", dt: float) -> list[events.Event]:
        """在 tick 开始前调用。"""
        super().before_step(world, dt)
        self._budget_add(world, dt)

    def after_step(self, world: "gw.GameWorld", dt: float) -> list[events.Event]:
        """在 tick 结束后调用。"""
        # 在帧最后刷新敌人， 给点反应时间
        self._try_spawn_enemy(world, dt)

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

    def _budget_add(self, world: "gw.GameWorld", dt: float):
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
            budget_data.budget += total_budget * budget_data.budget_weight

    def _try_spawn_enemy(self, world: "gw.GameWorld", dt: float):
        """尝试生成敌人。"""
        normal_enemy_type = ["enemy_slime", "enemy_skeleton", "enemy_runner"]

        for enemy_type, budget_data in self._enemy_budget.items():
            spawn_budget = self._survival_config.enemies[enemy_type].spawn_cost
            # 检查上限
            if world.enemy_count(normal_enemy_type) >= self._cur_stage.normal_alive_cap:
                break

            # 检查间隔

            # 检查预算
            if budget_data.budget >= spawn_budget:
                if self._real_spawn_enemy(world, enemy_type):
                    budget_data.budget -= spawn_budget


    def _real_spawn_enemy(self, world: "gw.GameWorld", enemy_type: str):
        """真实生成敌人。"""
        # 随便找一个玩家 生成在他周围
        players: list["entity.Entity"] = world.entities_with(PlayerComponent, TransformComponent)
        if not players:
            return

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
            else:
                break

        if idx >= 10:
            return False

        world.create_enemy(enemy_type, enemy_x, enemy_y)
        return True
