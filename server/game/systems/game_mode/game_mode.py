# coding=utf-8

import enum
import typing
import time
import game.events as events
if typing.TYPE_CHECKING:
    import game.command_router as command_router
    import game.world as gw

global_run_id = 0
def new_run_id() -> int:
    """生成新的运行 ID。"""
    global global_run_id
    global_run_id += 1
    return global_run_id


class CommandScope(enum.Enum):
    """游戏模式命令类型。"""
    LIFECYCLE = 1  # 不会被暂停
    GAMEPLAY = 2  # 会被暂停


class SystemScope(enum.Enum):
    """游戏模式系统类型。"""
    ALWAYS = 1  # 不会被暂停
    GAMEPLAY = 2  # 会被暂停


class GameModeType:
    """游戏模式类型。"""
    SURVIVAL = 1


class GameMode:
    """游戏模式。"""
    mode_type: GameModeType = GameModeType.SURVIVAL

    def __init__(self):
        self._gameplay_paused = False
        self._game_started = False
        self._start_time = 0.0
        self._start_tick = 0
        self._cur_tick = 0
        self._run_id = 0

    def start(self, world: "gw.GameWorld"):
        """开始游戏模式。"""
        self._game_started = True
        self._start_time = time.time()
        self._start_tick = world.cur_tick()
        self._run_id = new_run_id()

    def is_started(self) -> bool:
        """是否游戏已开始。"""
        return self._game_started

    def before_step(self, world: "gw.GameWorld", dt: float) -> list[events.Event]:
        """在 tick 开始前调用。"""
        self._cur_tick = world.cur_tick()

    def after_step(self, world: "gw.GameWorld", dt: float) -> list[events.Event]:
        """在 tick 结束后调用。"""
        pass

    def should_advance_gameplay(self) -> bool:
        """是否应该继续游戏。"""
        return not self._gameplay_paused

    def pause_gameplay(self):
        """暂停玩法时间，世界 tick 和生命周期命令仍会继续。"""
        self._gameplay_paused = True

    def resume_gameplay(self):
        """恢复玩法时间。"""
        self._gameplay_paused = False

    def can_dispatch_command(self, scope: CommandScope) -> bool:
        """判断指定范围的命令是否允许执行。"""
        if scope == CommandScope.LIFECYCLE:
            return True
        return self.should_advance_gameplay()

    def can_update_system(self, scope: SystemScope) -> bool:
        """判断指定范围的系统是否允许更新。"""
        if scope == SystemScope.ALWAYS:
            return True
        return self.should_advance_gameplay()

    def register_command_handlers(self, router: "command_router.CommandRouter"):
        """注册当前游戏模式特有的命令处理函数。"""
        pass

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

