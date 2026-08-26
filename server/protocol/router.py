# coding=utf-8
"""将每种客户端 payload 分发给唯一的 Command 构造 Handler。"""
from typing import Callable
from transport.connection_registry import ConnectionContext
from singleton import Singleton
from protocol.codec import ProtocolCodec
import proto.generated.game_pb2 as game_pb2

ClientHandler = Callable[[ConnectionContext, object], object]

@Singleton
class ClientMessageRouter:
    _handlers: dict[str, ClientHandler] = {}
    _allowed_kinds: set[str] = set()

    def __init__(self, allowed_kinds: set[str]):
        self._allowed_kinds = allowed_kinds
        self._handlers = {}

    def register(self, proto_name: str, handler: ClientHandler):
        if proto_name not in self._allowed_kinds:
            raise ValueError(f"ClientMessageRouter.register {proto_name} not allowed")

        if proto_name in self._handlers:
            raise ValueError(f"ClientMessageRouter.register {proto_name} already registered")

        self._handlers[proto_name] = handler        

    def to_command(self, context: ConnectionContext, message: game_pb2.ClientMessage) -> object | None:
        kind = message.WhichOneof("payload")
        if kind is None:
            raise ValueError("ClientMessage.payload is required")
        
        
        if kind in self._handlers:       
            return self._handlers[kind](context, getattr(message, kind))
        else:
            raise ValueError(f"ClientMessageRouter.to_command {kind} not registered")


        
