# coding=utf-8

import typing
if typing.TYPE_CHECKING:
    import game.world as gw

class GameMode:
    """游戏模式。"""

    def start(self, world: "gw.GameWorld"):
        """开始游戏模式。"""
        pass

    def before_step(self, world: "gw.GameWorld"):
        """在 tick 开始前调用。"""
        pass

    def after_step(self, world: "gw.GameWorld"):
        """在 tick 结束后调用。"""
        pass

    def should_advance_gameplay(self) -> bool:
        """是否应该继续游戏。"""
        return True

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

    