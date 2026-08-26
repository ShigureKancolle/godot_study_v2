# coding=utf-8
"""启动装配：注册协议路由和领域事件发布器。"""
from protocol import codec
from protocol import router
from protocol.handlers import login_handler
from protocol.handlers import game_handler
from transport.game_protocol_adapter import GameProtocolAdapter
import game.events as events



def build_client_router():
    '''注册协议路由'''
    client_router = router.ClientMessageRouter.get(set(codec.ProtocolCodec.get().client_payload_types.keys()))
    client_router.register("login_request", login_handler.login_handle)
    client_router.register("enter_game_request", game_handler.enter_game_request_handler)
    client_router.register("move_intent", game_handler.move_intent_handler)

def register_adapter(adapter: GameProtocolAdapter):
    adapter.register_event_handler(events.EntityJoinedEvent, adapter.publish_entity_joined)
    adapter.register_event_handler(events.EntityMovedEvent, adapter.to_movement_entry)
    adapter.register_event_handler(events.EntityRemovedEvent, adapter.publish_entity_removed)
    adapter.register_event_handler(events.CommandRejectedEvent, adapter.publish_command_rejected)
