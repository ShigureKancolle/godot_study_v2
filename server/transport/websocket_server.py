# coding=utf-8

import websockets
import asyncio
from transport.connection_registry import ConnectionRegistry, ConnectionContext
from transport.outbound_queue import OutBoundQueue
from protocol.router import ClientMessageRouter
from protocol.codec import ProtocolCodec

HOST = "127.0.0.1"
PORT = 8765

class WebSocketServer:
    def __init__(self, host: str = HOST, port: int = PORT):
        self.registry = ConnectionRegistry.get()
        self.outbound_queue = OutBoundQueue.get()
        self.host = host
        self.port = port
        self.is_running = False
        self.sender_task = None

    async def start(self):
        self.is_running = True
        # 启动发送循环
        self.sender_task = asyncio.create_task(self.sender_loop())

        async with websockets.serve(self.handle, self.host, self.port):
            print(f"server start at {self.host}:{self.port}")
            await asyncio.Future()

        

    async def handle(self, websocket: websockets.WebSocketCommonProtocol):
        print("客户端已连接")
        context: ConnectionContext = self.registry.add(websocket)
        try:
            print("等待客户端信息。。。")
            async for payload in websocket:
                if not isinstance(payload, bytes):
                    print(f"收到非protobuf客户端信息：{payload}")
                    continue
                await self.on_bytes_received(context, payload)

        except websockets.ConnectionClosed:
            print("客户端已断开")
        finally:
            self.registry.remove(context.connection_id)
            print(f"移除客户端，当前人数： {len(self.registry.all_connections())}")

    async def on_bytes_received(self, context: ConnectionContext, payload: bytes):
        # 怎么在这里分辨login请求 然后绑定account_id
        # 怎么把各种协议分发出去
        message = ProtocolCodec.get().decode_client(payload)
        ClientMessageRouter.get().to_command(context, message)


    async def sender_loop(self):
        while self.is_running:
            packet = await self.outbound_queue.next_packet()

            for context in self.registry.all_connections():
                if context.connection_id in packet.recipient_ids:
                    await context.websocket.send(packet.payload)

    def close(self):
        self.is_running = False
        if self.sender_task is not None:
            self.sender_task.cancel()
            self.sender_task = None
