# coding=utf-8
'''
从proto的角度判断消息是否能发送， 检查发送路径和参数 
'''

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
}

def validate_client_message(client_message):
    kind = client_message.WhichOneof("message_type")

    if kind is None:
        print("非法客户端消息")
        return False

    # 针对每一种请求做最基础的字段检查
    # 例如 account 不能为空、dir_x/dir_y 是有限数字

    # (这个地方一个个检查不是会撑爆文件？ 检查这个的意义是什么？)
    return True