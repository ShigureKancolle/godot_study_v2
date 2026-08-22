extends Singleton
class_name WebSocketMgr

const GameProto = preload("../proto/game_proto.gd")

static var _instance: WebSocketMgr = null

static func Get_Ins() -> WebSocketMgr:
	return _instance

static func Get() -> WebSocketMgr:
	if not _instance:
		_instance = WebSocketMgr.new()
	return _instance

var HOST = "127.0.0.1"
var PORT = 8765
var wsp: WebSocketPeer = WebSocketPeer.new()

func start() -> void:
	wsp.connect_to_url("ws://{0}:{1}".format([HOST, PORT]))
	
func poll(delta: float) -> void:
	wsp.poll()
	var state = wsp.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		while wsp.get_available_packet_count():
			var packet := wsp.get_packet()
			print("数据包：", packet)
			MessageRouter.Get().route(packet)
	elif state == WebSocketPeer.STATE_CLOSING:
		# 继续轮询才能正确关闭。
		pass
	elif state == WebSocketPeer.STATE_CLOSED:
		pass

# 先写死一个发送登录的方法 之后再改成服务端那样通用的
func send_login(acc: String, name: String) -> Error:
	if wsp.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ERR_UNAVAILABLE

	var envelope := GameProto.ClientMessage.new()
	var request := envelope.new_login_request()
	request.set_account(acc.strip_edges())
	request.set_player_name(name.strip_edges())

	return wsp.send(envelope.to_bytes())

func send():
	pass
