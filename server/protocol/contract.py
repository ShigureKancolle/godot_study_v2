# coding=utf-8
"""在协议边界校验 Protobuf 请求结构和标量取值范围。"""
import math
'''
“这是 MoveIntent 吗？方向字段是合法的吗？”
→ Contract

“这个玩家是否死亡，能否移动？”
→ MovementSystem
'''


CLIENT_MESSAGE_TYPES = {
    "login_request",
    "enter_game_request",
    "move_intent",
}


SERVER_MESSAGE_TYPES = {
    "login_accepted",
    "world_snapshot",
    "movement_frame",
    "entity_spawned",
    "entity_removed",
    "entity_relocated",
    "command_rejected",
}


class ProtocolValidationError(ValueError):
    """可返回客户端且不应导致连接断开的请求错误。"""

    def __init__(self, command_name: str, reason_code: str, reason_message: str):
        super().__init__(reason_message)
        self.command_name = command_name
        self.reason_code = reason_code
        self.reason_message = reason_message


def _required_text(value: str, command_name: str, field_name: str) -> str:
    normalized = value.strip()
    if not normalized:
        raise ProtocolValidationError(
            command_name,
            "REQUIRED_FIELD",
            f"{field_name} 为必填字段",
        )
    return normalized


def validate_login_request(message):
    account = _required_text(message.account, "login_request", "account")
    player_name = _required_text(message.player_name, "login_request", "player_name")
    return account, player_name


def validate_enter_game_request(message):
    player_name = _required_text(message.player_name, "enter_game_request", "player_name")
    return player_name


def validate_move_intent(message):
    if not math.isfinite(message.dir_x) or not math.isfinite(message.dir_y):
        raise ProtocolValidationError(
            "move_intent",
            "NON_FINITE_DIRECTION",
            "dir_x 和 dir_y 必须是有限数",
        )

def validate_attack_intent(message):
    if not math.isfinite(message.attack_id):
        raise ProtocolValidationError(
            "attack_intent",
            "NON_FINITE_DIRECTION",
            "attack_id 必须是有限数",
        )
    

    attacker_id = _required_text(message.attacker_id, "attack_intent", "attacker_id")
    attack_id = message.attack_id
   
    return attacker_id, attack_id


def validate_client_message(client_message):
    kind = client_message.WhichOneof("payload")

    if kind is None:
        raise ProtocolValidationError("unknown", "PAYLOAD_REQUIRED", "ClientMessage.payload 为必填字段")

    # 针对每一种请求做最基础的字段检查
    # 例如 account 不能为空、dir_x/dir_y 是有限数字

    # (这个地方一个个检查不是会撑爆文件？ 检查这个的意义是什么？)
    validator = {
        "login_request": validate_login_request,
        "enter_game_request": validate_enter_game_request,
        "move_intent": validate_move_intent,
    }.get(kind)
    if validator is not None:
        validator(getattr(client_message, kind))
    return True

def validate_atk_rotate_intent(message):
    if not math.isfinite(message.atk_facing):
           raise ProtocolValidationError(
               "atk_rotate_intent",
               "NON_FINITE_DIRECTION",
               "atk_facing 必须是有限数",
           )

    atk_facing = message.atk_facing
    entity_id = _required_text(message.entity_id, "atk_rotate_intent", "entity_id")
   
    return atk_facing, entity_id
