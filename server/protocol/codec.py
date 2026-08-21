# coding=utf-8
'''
编码解码器
'''
import proto.generated.game_pb2 as game_pb2
from google.protobuf.json_format import MessageToDict, ParseDict

# 不应该做这些事
# 查 GameWorld
# 查连接
# 生成 Command
# 调用 WebSocket.send

class ProtocolCodec:
    def decode_client(payload: bytes) -> game_pb2.ClientMessage:
        message = game_pb2.ClientMessage()
        message.ParseFromString(payload)
        return message

    def encode_server(message: game_pb2.ServerMessage) -> bytes:
        return message.SerializeToString()