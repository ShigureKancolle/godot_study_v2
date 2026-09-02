# coding=utf-8
"""统一控制网络协议调试输出。"""

import os


_HIGH_FREQUENCY_PROTOCOLS = frozenset({
    "world_frame",
})

# 默认不打印高频帧；排查网络同步时设置为 1 可临时打开。
_SHOW_HIGH_FREQUENCY_PROTOCOLS = os.getenv(
    "SHOW_HIGH_FREQUENCY_PROTOCOLS", "0"
) == "1"


def should_log_protocol(proto_name: str) -> bool:
    """判断指定协议是否应输出调试信息。"""
    return (
        proto_name not in _HIGH_FREQUENCY_PROTOCOLS
        or _SHOW_HIGH_FREQUENCY_PROTOCOLS
    )
