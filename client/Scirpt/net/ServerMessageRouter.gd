extends Singleton
class_name MessageRouter
const GameProto = preload("../proto/game_proto.gd")

static var _instance: MessageRouter = null

static func Get_Ins() -> MessageRouter:
	return _instance

static func Get() -> MessageRouter:
	if not _instance:
		_instance = MessageRouter.new()
	return _instance

# 先写死在这 之后解耦
var _handlers := {
	GameProto.ServerMessage.PayloadCase.LOGIN_ACCEPTED: _on_login_accepted,
}

func _on_login_accepted(msg: GameProto.ServerMessage):
	var login_accepted = msg.get_login_accepted()
	print("登录成功, account: ", login_accepted.get_account(), "  name: ",login_accepted.get_player_name())


func route(raw: PackedByteArray) -> void:
	var message := GameProto.ServerMessage.new()
	var result := message.from_bytes(raw)
	if result != GameProto.PB_ERR.NO_ERRORS:
		push_error("解析消息失败")
		return

	var handler = _handlers.get(message.get_payload_case())
	if not handler.is_valid():
		push_error("未注册的处理函数")
		return

	handler.call(message)
	
