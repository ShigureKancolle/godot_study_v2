extends Singleton
class_name MessageRouter
## 将解码后的 ServerMessage payload 路由给已注册的客户端 Handler。
const GameProto = preload("../proto/game_proto.gd")

static var _instance: MessageRouter = null

static func Get_Ins() -> MessageRouter:
	return _instance

static func Get() -> MessageRouter:
	if not _instance:
		_instance = MessageRouter.new()
	return _instance

# 先写死在这 之后解耦
var _handlers: Dictionary[StringName, Callable] = {}
#:= {
	#&"login_accepted": _on_login_accepted,
#}


func register(proto_name: StringName, callable: Callable):
	if not GameProto.ServerMessage.new().has_method("get_" + String(proto_name)):
		push_error("不存在的proto消息 " + proto_name)
		return
		
	if proto_name in _handlers:
		push_error("已经注册过的消息")
		return
		
	_handlers[proto_name] = callable

func route(raw: PackedByteArray) -> void:
	var message := GameProto.ServerMessage.new()
	var result := message.from_bytes(raw)
	if result != GameProto.PB_ERR.NO_ERRORS:
		push_error("解析消息失败")
		return
		
	var payload_name := _get_payload_name(message)	
		
	var handler = _handlers.get(payload_name)
	if not handler or not handler.is_valid():
		push_error("未注册的处理函数  " + payload_name)
		return
		
	handler.call(message)
	
func _get_payload_name(msg: GameProto.ServerMessage) -> String:
	var payload_tag := msg.get_payload_case()
	if payload_tag == GameProto.ServerMessage.PayloadCase.PAYLOAD_NOT_SET:
		return &""
		
	var service = msg.data.get(payload_tag)
	if service == null:
		return &""
		
	return StringName(service.field.name)
	
	
	
