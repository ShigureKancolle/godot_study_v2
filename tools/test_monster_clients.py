# coding=utf-8
"""启动两个现有 Godot 客户端，以真实 WebSocket 和领域投影验证怪物快照与攻击表现。"""

import argparse
import asyncio
import json
import math
from pathlib import Path
import subprocess
import sys

import websockets

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "server"))

from game.entity_projector import project_entity_snapshot
from game.events import EntityAttackStartEvent
from game.model import config_loader
from game.world import GameWorld
from proto.generated import game_pb2
from transport.game_proto_projector import GameProtoProjector


async def run(godot: str):
    """每个进程独立解码、更新 GameStore、创建视图并回传断言结果。"""
    world = GameWorld()
    enemies = [world.create_enemy(key, index * 220.0, 100.0) for index, key in enumerate(config_loader.get_survival_config().enemies)]
    snapshot = game_pb2.ServerMessage(run_id="monster_validation", server_tick=1)
    snapshot.world_snapshot.room_id = "monster_validation"
    snapshot.world_snapshot.server_tick = 1
    for enemy in enemies:
        snapshot.world_snapshot.entities.add().CopyFrom(GameProtoProjector.entity_info(project_entity_snapshot(enemy)))
    frame = game_pb2.ServerMessage(run_id="monster_validation", server_tick=2)
    for enemy in enemies:
        ai = config_loader.get_entity_ai_config(config_loader.get_capability(enemy.entity_config_key).ai_id)
        frame.world_frame.events.add().CopyFrom(GameProtoProjector.attack_start(EntityAttackStartEvent(enemy.entity_id, ai.attack_id, math.pi / 2)))
    clients = []
    responses = []
    connected = asyncio.Event()

    async def handle(socket):
        clients.append(socket)
        if len(clients) == 2:
            connected.set()
        await asyncio.wait_for(connected.wait(), 25)
        await socket.send(snapshot.SerializeToString())
        await socket.send(frame.SerializeToString())
        responses.append(json.loads(await asyncio.wait_for(socket.recv(), 20)))
        await socket.wait_closed()

    log_dir = ROOT / ".tmp/monster_validation"
    log_dir.mkdir(parents=True, exist_ok=True)
    processes = []
    streams = []
    async with websockets.serve(handle, "127.0.0.1", 0) as server:
        port = server.sockets[0].getsockname()[1]
        try:
            for index in range(2):
                command = [godot, "--headless", "--path", str(ROOT / "client"), "--script", "res://Tests/MonsterPresentationTest.gd", "--log-file", str(log_dir / f"network_client_{index + 1}.log"), "--", f"--network-url=ws://127.0.0.1:{port}"]
                stream = (log_dir / f"network_client_{index + 1}_console.log").open("wb")
                streams.append(stream)
                processes.append(subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0))
            await asyncio.wait_for(asyncio.gather(*(asyncio.to_thread(process.wait) for process in processes)), 50)
            assert all(process.returncode == 0 for process in processes), "客户端非零退出，查看 network_client 日志"
            assert len(responses) == 2, f"只收到 {len(responses)} 个客户端验收结果"
            assert all(item["monsters"] == 5 and item["attacks"] == 5 and not item["failures"] for item in responses), responses
            result = {"status": "passed", "clients": responses, "transport": "websocket+protobuf", "scope": "怪物快照与攻击表现同步，不包含完整生存局玩法"}
            (log_dir / "two_clients.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
            print(json.dumps(result, ensure_ascii=False))
        finally:
            for process in processes:
                if process.returncode is None:
                    process.kill()
                    await asyncio.to_thread(process.wait)
            for stream in streams:
                stream.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    asyncio.run(run(parser.parse_args().godot))
