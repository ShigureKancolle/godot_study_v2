# coding=utf-8
"""编码服务端消息，并按目标连接将数据包放入发送队列。"""
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
    proto_name: str = ""

@Singleton
class OutBoundQueue:
    queue: asyncio.Queue[OutBoundMessage] = asyncio.Queue()

    def send_to(self, connection_id: int, proto_name: str, body: Message, *args, run_id: str = "", server_tick: int = 0):
        '''
            body 是具体的协议  LoginAccepted, MovementFrame....
        '''
        print(f"OutBoundQueue.send_to   proto_name: {proto_name}, body: {body}")
        print(f"run_id: {run_id},  server_tick: {server_tick}")
        # 构建协议
        payload = ProtocolCodec.get().encode_server(proto_name, body, run_id=run_id, server_tick=server_tick)

        # 传给指定连接
        self.queue.put_nowait(OutBoundMessage(payload=payload, recipient_ids=[connection_id], proto_name=proto_name))

    def broadcast(self, proto_name: str, body: Message, include_ids: list[int] | None = None, exclude_ids: list[int] | None = None, room_id: str = "", run_id: str = "", server_tick: int = 0):
        include_ids = include_ids or []
        exclude_ids = exclude_ids or []
        print(f"OutBoundQueue.broadcast   proto_name: {proto_name}, body: {body}")
        print(f"room_id: {room_id},  exclude_ids: {exclude_ids}")
        payload = ProtocolCodec.get().encode_server(proto_name, body, run_id=run_id, server_tick=server_tick)

        def check_context(context: connection_registry.ConnectionContext):
            # include_ids不传代表所有连接
            if include_ids and context.connection_id not in include_ids:
                return False

            if room_id and context.room_id != room_id:
                return False

            if context.connection_id in exclude_ids:
                return False

            return True

        ids = [context.connection_id for context in connection_registry.ConnectionRegistry.get().all_connections() if check_context(context)]
        # 广播给所有人
        self.queue.put_nowait(OutBoundMessage(payload=payload, recipient_ids=ids, proto_name=proto_name))

    async def next_packet(self):
        # 获取下一个包
        return await self.queue.get()
