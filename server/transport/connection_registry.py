# coding=utf-8
'''
注册协议事件
'''
import typing
from typing import Callable

web_scoket_hanler: dict[str, Callable] = {}

def onproto(protoname: str):
    def decorator(func: Callable):
        full_name = resolve_name(protoname)
        web_scoket_hanler[full_name] = func
        print(f"注册处理器: {protoname} -> {func.__name__} (全名: {full_name})")
        return func

    return decorator

def resolve_name(protoname: str) -> str:
    """
    解析消息名：支持全名和短名

    - 全名（含 '.'）直接查注册表
    - 短名查 _short_to_full：唯一则返回全名，多个则报错要求用全名
    
    """

    # TODO 暂不支持
    return protoname

    