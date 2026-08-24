extends Node
'''
用于组装初始化客户端
'''

var web_socket_mgr: WebSocketMgr = null

func _ready():
	# 网络服务
	web_socket_mgr = WebSocketMgr.Get()
	web_socket_mgr.start()
	
	# 网络消息
	HandlerRegister.register()
	
func create_game_room() -> GameStore:
	# 创建一个房间需要的各种实例 然后运行起来
	var room = GameStore.new()
	return room

func _process(delta: float) -> void:
	web_socket_mgr.poll(delta)
