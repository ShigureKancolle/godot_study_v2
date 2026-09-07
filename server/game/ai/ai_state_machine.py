# coding=utf-8
"""AI状态机。"""

import game.ai.ai_statebase as ai_state

class AIStateMachine:
    """AI状态机。"""
    _cur_state: ai_state.AIStateBase = None
    _next_state: ai_state.AIStateBase = None

    def change_state(self, state: ai_state.AIStateBase):
        """改变状态。"""
        self._next_state = state

    def update(self):
        """更新状态。"""
        if self._next_state is not None:
            self._cur_state = self._next_state
            self._next_state = None


    def get_cur_state(self) -> ai_state.AIStateBase:
        """获取当前状态。"""
        return self._cur_state

    def get_next_state(self) -> ai_state.AIStateBase:
        """获取下一个状态。"""
        return self._next_state or self._cur_state

    