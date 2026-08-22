# coding=utf-8
'''
编码解码器
'''
from google.protobuf.message import Message
import proto.generated.game_pb2 as game_pb2
from google.protobuf.json_format import MessageToDict, ParseDict
from singleton import Singleton

@Singleton
class ProtocolCodec:
    client_payload_types: dict[str, tuple[type, str]] = {}
    server_payload_types: dict[str, tuple[type, str]] = {}

    def __init__(self):
        self.client_payload_types = self._payload_types(game_pb2.ClientMessage)
        self.server_payload_types = self._payload_types(game_pb2.ServerMessage)

    @staticmethod
    def _payload_types(evenope_type: type[Message]) -> dict[str, type[Message]]:
        oneof = evenope_type.DESCRIPTOR.oneofs_by_name["payload"]
        return {
            field.name: getattr(game_pb2, field.message_type.name)
            for field in oneof.fields
        }

    def decode_client(self, raw: bytes) -> game_pb2.ClientMessage:
        message = game_pb2.ClientMessage()
        message.ParseFromString(raw)
        if message.WhichOneof("payload") is None:
            raise ValueError("ClientMessage.payload is required")

        return message

    def encode_server(self, proto_name: str, body: Message, *args, run_id: str = "", server_tick: int = 0) -> bytes:
        expect_type = self.server_payload_types.get(proto_name)
        if expect_type is None:
            raise ValueError(f"ServerMessage {proto_name} not found")

        if not isinstance(body, expect_type):
            raise ValueError(f"ServerMessage {proto_name} body type must be {expect_type.__name__}")

        envelope = game_pb2.ServerMessage(
            run_id = run_id,
            server_tick = server_tick,
        )

        getattr(envelope, proto_name).CopyFrom(body)
        return envelope.SerializeToString()