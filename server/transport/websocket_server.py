# coding=utf-8

import websockets
import asyncio
import logging
from transport.connection_registry import ConnectionRegistry, ConnectionContext
from transport.outbound_queue import OutBoundQueue
from protocol.router import ClientMessageRouter
from protocol.codec import ProtocolCodec
from game import commands, world

HOST = "127.0.0.1"
PORT = 8765

logger = logging.getLogger(__name__)

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
        self.sender_task = asyncio.create_task(
            self.sender_loop(),
            name="webscoket-sender"
        )
        self.sender_task.add_done_callback(self._on_sender_task_done)

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
                try:
                    await self.on_bytes_received(context, payload)
                except Exception:
                    # 协议格式或某个业务 handler 出错时，不要让异常离开
                    # handle()；否则 async for 会结束，finally 会将客户端移除。
                    # 记录完整 traceback，随后继续处理这条连接的下一条消息。
                    logger.exception(
                        "处理客户端消息失败：connection_id=%s, payload_size=%s",
                        context.connection_id,
                        len(payload),
                    )

        except websockets.ConnectionClosed:
            print("客户端已断开")
        finally:
            entity_id = context.player_entity_id
            account = context.account_id
            room_id = context.room_id
            self.registry.remove(context.connection_id)
            if entity_id:
                game_world = world.get_room()

                if game_world.room_id == room_id:
                    game_world.enqueue_command(
                        commands.LeaveCommand(
                            entity_id,
                            account
                        )
                    )


            print(f"移除客户端，当前人数： {len(self.registry.all_connections())}")

    async def on_bytes_received(self, context: ConnectionContext, payload: bytes):
        # 怎么在这里分辨login请求 然后绑定account_id
        # 怎么把各种协议分发出去
        message = ProtocolCodec.get().decode_client(payload)
        ClientMessageRouter.get().to_command(context, message)

    async def _on_sender_task_done(self, task: asyncio.Task):
        if task.cancelled():
            return

        exception = task.exception()

        if exception is None:
            return

        logger.error(
            "websocket 发送任务异常退出",
            exc_info=(
                type(exception),
                exception,
                exception.__traceback__
            )
        )


    async def sender_loop(self):
        while self.is_running:
            packet = await self.outbound_queue.next_packet()

            for context in self.registry.all_connections():
                if context.connection_id in packet.recipient_ids:
                    try:
                        print(f"WebSocketServer.sender_loop   proto_name: {packet.proto_name}")
                        await context.websocket.send(packet.payload)
                    except websockets.ConnectionClosed:
                        # 接收协程的 finally 会负责删除这个连接；这里不能让一个
                        # 已关闭连接停止所有客户端的发送循环。
                        logger.info("发送时客户端已断开：connection_id=%s", context.connection_id)
                    except Exception:
                        logger.exception(
                            "发送消息失败：connection_id=%s, proto_name=%s",
                            context.connection_id,
                            packet.proto_name,
                        )

    def close(self):
        self.is_running = False
        if self.sender_task is not None:
            self.sender_task.cancel()
            self.sender_task = None
