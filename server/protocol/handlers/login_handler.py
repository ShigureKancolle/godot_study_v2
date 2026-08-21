# coding=utf-8

from transport.connection_registry import onproto

@onproto("game.LoginRequest")
def login(acc: str):
    print(f"player login acc: {acc}")

    # TODO 直接返回 LoginAccepted