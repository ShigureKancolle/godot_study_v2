# coding=utf-8

''' 
客户端请求 
服务端经过验证后更新游戏状态并返回事件通知客户端
'''
from dataclasses import dataclass, field

@dataclass
class Command:
    entity_id: str = ""

@dataclass
class MoveCommand(Command):
    ''' 客户端移动请求 '''
    dir_x: float = 0.0
    dir_y: float = 0.0
    moving: bool = False

@dataclass
class JoinCommand(Command):
    ''' 客户端加入游戏请求 '''
    account: str = ""

@dataclass 
class AttackCommand(Command):
    ''' 客户端攻击请求 '''
    attack_id: int = 0



    
