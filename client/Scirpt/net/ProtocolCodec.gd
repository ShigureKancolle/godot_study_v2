extends Singleton
class_name ProtocolCodec
## 根据请求名称和标量字典构建 ClientMessage Protobuf 包络。

static var _instance: ProtocolCodec = null

static func Get_Ins() -> ProtocolCodec:
	return _instance

static func Get() -> ProtocolCodec:
	if not _instance:
		_instance = ProtocolCodec.new()
	return _instance

const game_pb = preload("../proto/game_proto.gd")   

var _registry: Dictionary = {}
var _gm_classes: Array = []

func decode_server(payload: PackedByteArray) -> Dictionary:
	for entry in _gm_classes:
		var gm_class = entry["class"]
		var package: String = entry["package"]
		var game_msg = gm_class.new()
		var err: int = game_msg.from_bytes(payload)
		if err != game_pb.PB_ERR.NO_ERRORS:
			continue

		var matched: Array = []
		for tag in game_msg.data:
			var service = game_msg.data[tag]
			if service.state != game_pb.PB_SERVICE_STATE.FILLED:
				continue
			var field_name: String = service.field.name
			print("package: ", package, "  field_name: ", field_name)
			matched.append(service)

		if matched.is_empty():
			continue
	return {}


func encode_client(proto_name: String, proto_params: Dictionary):
	var msg := game_pb.ClientMessage.new()
	var create_func_name = "new_" + proto_name

	if not msg.has_method(create_func_name):
		print_debug("未知的协议  " + proto_name)
		return null

	var proto_ins = msg.call(create_func_name)


	_fill_message(proto_ins, proto_params)
	var data: PackedByteArray = msg.to_bytes()
	return data




	# var entry: Dictionary = get_msg_register(proto_name)
	# var gm_class = entry["gm_class"]
	# var field_name: String = entry["field_name"]

	# var game_msg = gm_class.new()
	# var sub_msg = game_msg.call("new_" + field_name)
	# _fill_message(sub_msg, proto_params)

	# var data: PackedByteArray = game_msg.to_bytes()
	# return data

func get_msg_register(proto_name: String):
	return _registry[proto_name]

# 字典 -> protobuf 消息对象（递归）
func _fill_message(msg, data: Dictionary) -> void:
	if data == null:
		return
	for key in data:
		var value = data[key]
		if msg.has_method("new_" + key):
			var sub = msg.call("new_" + key)
			_fill_message(sub, value)
		elif msg.has_method("add_" + key):
			for item in value:
				var element = msg.call("add_" + key)
				_fill_message(element, item)
		elif msg.has_method("set_" + key):
			msg.call("set_" + key, value)
		elif msg.has_method("get_" + key):
			var arr = msg.call("get_" + key)
			if value is Array:
				for item in value:
					arr.append(item)
			else:
				arr.append(value)
