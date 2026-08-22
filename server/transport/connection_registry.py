# coding=utf-8
'''
注册连接 上下文
'''
import typing
from typing import Any
from typing import Callable
import dataclasses
from proto.generated import game_pb2
from singleton import Singleton
import websockets
    
    
connection_id: int = 0
def get_new_connection_id():
    global connection_id
    connection_id += 1
    return connection_id


@dataclasses.dataclass
class ConnectionContext:
    connection_id: int
    websocket: websockets.WebSocketProtocol
    account_id: str = ""
    player_name: str = ""
    player_entity_id: str = ""

@Singleton
class ConnectionRegistry:
    connection_by_id: dict[int, ConnectionContext] = {}

    def add(self, websocket: websockets.WebSocketProtocol) -> ConnectionContext:
        # 分配connection_id  记录socket
        context = ConnectionContext(get_new_connection_id(), websocket)
        self.connection_by_id[context.connection_id] = context
        return context

    def remove(self, connection_id: int):
        context = self.connection_by_id.pop(connection_id, None)
        if context:
            del context

    def bind_account(self, connection_id: int, account_id: str, player_name: str):
        context = self.connection_by_id.get(connection_id, None)
        if context:
            context.account_id = account_id
            context.player_name = player_name

    def get_context(self, connection_id: int):
        return self.connection_by_id.get(connection_id, None)

    def all_connections(self) -> list[ConnectionContext]:
        return list(self.connection_by_id.values())

          

    