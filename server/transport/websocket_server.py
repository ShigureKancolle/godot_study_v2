# coding=utf-8

import websockets
import asyncio

HOST = "127.0.0.1"
PORT = 8765

clients = set()

class WebSocketServer:
    def __init__(self, host: str = HOST, port: int = PORT):
        self.host = host
        self.port = port

    async def start(self):
        async with websockets.serve(self.handle, self.host, self.port):
            print(f"server start at {self.host}:{self.port}")
            await asyncio.Future()

    async def handle(self, websocket):
        print("客户端已连接")
        clients.add(websocket)
        try:
            print("等待客户端信息。。。")
            async for message in websocket:
                print(f"收到客户端信息：{message}")
                if clients:
                    await asyncio.gather(*[client.send(message) for client in clients])

        except websockets.ConnectionClosed:
            print("客户端已断开")
        finally:
            clients.remove(websocket)
            print(f"移除客户端，当前人数： {len(clients)}")


    def close(self):
        pass