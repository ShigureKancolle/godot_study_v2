# coding=utf-8
"""启动装配：注册协议路由和领域事件发布器。"""
from protocol import codec
from protocol import router
from protocol.handlers import login_handler
from protocol.handlers import game_handler
from protocol.handlers import combat_handler

from transport.game_protocol_adapter import GameProtocolAdapter
import game.events as events



def build_client_router():
    '''注册协议路由'''
    client_router = router.ClientMessageRouter.get(set(codec.ProtocolCodec.get().client_payload_types.keys()))
    client_router.register("login_request", login_handler.login_handle)
    client_router.register("enter_game_request", game_handler.enter_game_request_handler)
    client_router.register("move_intent", game_handler.move_intent_handler)
    client_router.register("attack_intent", game_handler.attack_intent_handler)
    client_router.register("atk_rotate_intent", combat_handler.atk_rotate_intent_handler)
