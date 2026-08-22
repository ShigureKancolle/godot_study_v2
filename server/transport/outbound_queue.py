# coding=utf-8
'''
排队发送协议
'''
from google.protobuf.message import Message
from dataclasses import dataclass, field
from protocol.codec import ProtocolCodec
import transport.connection_registry as connection_registry
import asyncio
from singleton import Singleton

@dataclass
class OutBoundMessage:
    payload: bytes
    recipient_ids: list[int] = field(default_factory=list) # 接收者连接id列表  connection_id

@Singleton
class OutBoundQueue:
    queue: asyncio.Queue[OutBoundMessage] = asyncio.Queue()

    def send_to(self, connection_id: int, proto_name: str, body: Message):
        '''
            body 是具体的协议  LoginAccepted, MovementFrame....
        '''

        # 构建协议
        payload = ProtocolCodec.get().encode_server(proto_name, body)

        # 传给指定连接
        self.queue.put_nowait(OutBoundMessage(payload=payload, recipient_ids=[connection_id]))

    def broadcast(self, proto_name: str, body: Message):
        payload = ProtocolCodec.get().encode_server(proto_name, body)

        # 广播给所有人
        self.queue.put_nowait(OutBoundMessage(payload=payload, recipient_ids=connection_registry.ConnectionRegistry.get().all_connections()))

    async def next_packet(self):
        # 获取下一个包
        return await self.queue.get()
