extends Singleton
class_name WebSocketMgr

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
			print("数据包：", wsp.get_packet())
	elif state == WebSocketPeer.STATE_CLOSING:
		# 继续轮询才能正确关闭。
		pass
	elif state == WebSocketPeer.STATE_CLOSED:
		pass

func send():
	pass
