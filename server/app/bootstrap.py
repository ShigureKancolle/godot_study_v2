# coding=utf-8
from protocol import codec
from protocol import router
from protocol.handlers import login_handler
from protocol.handlers import game_handler


def build_client_router():
    '''注册协议路由'''
    client_router = router.ClientMessageRouter.get(set(codec.ProtocolCodec.get().client_payload_types.keys()))
    client_router.register("login_request", login_handler.login_handle)
    client_router.register("enter_game_request", game_handler.enter_game_request_handler)
