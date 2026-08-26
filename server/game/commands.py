# coding=utf-8

"""由客户端请求或连接生命周期事件生成的应用命令。

SessionCommand 面向连接和会话状态；WorldCommand 进入队列后只能由游戏 System
应用到 GameWorld。
"""
from dataclasses import dataclass

@dataclass
class WorldCommand:
    entity_id: str = ""
    connection_id: int = 0

@dataclass
class MoveCommand(WorldCommand):
    ''' 客户端移动请求 '''
    dir_x: float = 0.0
    dir_y: float = 0.0
    moving: bool = False

@dataclass
class JoinCommand(WorldCommand):
    ''' 客户端加入游戏请求 '''
    account: str = ""
    player_name: str = ""

@dataclass 
class AttackCommand(WorldCommand):
    ''' 客户端攻击请求 '''
    attack_id: int = 0

@dataclass
class LeaveCommand(WorldCommand):
    account: str = ""

@dataclass
class SessionCommand:
    connection_id: int = 0
    account: str = ""

@dataclass
class LoginCommand(SessionCommand):
    """认证并绑定连接；该命令不会进入 GameWorld。"""

    player_name: str = ""
